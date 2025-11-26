// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ReentrancyGuard} from "./libraries/ReentrancyGuard.sol";
import {AaveConnector} from "./AaveConnector.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {OrderQueue} from "./libraries/OrderQueue.sol";

/**
 * @title LendingMatchingEngine
 * @notice Gas-efficient P2P lending matching engine with Aave integration
 * @dev Features: rate buckets, term buckets, collateralized loans, keeper rewards
 */
contract LendingMatchingEngine is AaveConnector, ReentrancyGuard {
    using OrderQueue for OrderQueue.Queue;

    // Custom errors for gas efficiency
    error InvalidAmount();
    error InvalidRate();
    error InvalidTerm();
    error InsufficientCollateral();
    error LoanNotFound();
    error NotBorrower();
    error NotLender();
    error LoanNotDue();
    error AlreadyRepaid();
    error Undercollateralized();
    error NoMatchesFound();

    // Events
    event LenderDeposit(uint256 indexed orderId, address indexed lender, uint96 amount, uint16 minRateBps, uint8 term);
    event BorrowRequest(uint256 indexed orderId, address indexed borrower, uint96 amount, uint16 maxRateBps, uint8 term, uint96 collateral);
    event Matched(uint256 indexed loanId, uint256 lenderOrderId, uint256 borrowOrderId, address lender, address borrower, uint96 amount, uint16 rateBps, uint8 term);
    event Repaid(uint256 indexed loanId, address indexed borrower, uint96 principal, uint96 interest);
    event Withdrawn(address indexed user, uint96 amount);
    event LenderCancelled(uint256 indexed orderId, address indexed lender, uint96 amount);
    event BorrowerCancelled(uint256 indexed orderId, address indexed borrower, uint96 collateral);
    event Liquidated(uint256 indexed loanId, address indexed liquidator, uint96 collateralSeized);
    event KeeperRewarded(address indexed keeper, uint96 reward);

    // State variables
    OrderQueue.Queue private lenderQueue;
    OrderQueue.Queue private borrowQueue;

    mapping(uint256 => DataTypes.LenderOrder) public lenderOrders;
    mapping(uint256 => DataTypes.BorrowOrder) public borrowOrders;
    mapping(uint256 => DataTypes.LoanPosition) public loans;

    // User balances (for withdrawals)
    mapping(address => uint96) public userBalances;

    // Counters
    uint256 public nextLenderOrderId;
    uint256 public nextBorrowOrderId;
    uint256 public nextLoanId;

    // Keeper reward pool (1% of interest goes to keeper reward pool)
    uint96 public keeperRewardPool;
    uint16 constant KEEPER_REWARD_BPS = 100; // 1%
    uint96 constant MIN_KEEPER_REWARD = 1e6; // Minimum 1 USDC reward

    // Collateral price oracle (simplified - using 1:1 for USDC collateral)
    // In production, use Chainlink or similar
    uint256 constant COLLATERAL_PRICE = 1e18; // 1 USDC = 1 USD

    /**
     * @notice Constructor
     * @param _aavePool Aave V3 Pool address
     * @param _underlyingAsset Underlying asset (USDC)
     * @param _aToken aToken address (aUSDC)
     */
    constructor(address _aavePool, address _underlyingAsset, address _aToken)
        AaveConnector(_aavePool, _underlyingAsset, _aToken)
    {}

    /**
     * @notice Lender deposits funds to lend
     * @param amount Amount to lend
     * @param minRateBps Minimum acceptable rate in basis points
     * @param term Term bucket (0=7d, 1=30d, 2=90d)
     */
    function depositLender(uint96 amount, uint16 minRateBps, uint8 term) external nonReentrant returns (uint256 orderId) {
        if (amount == 0) revert InvalidAmount();
        if (term > 2) revert InvalidTerm();
        if (minRateBps > 10000) revert InvalidRate();

        // Transfer tokens from lender
        underlyingAsset.transferFrom(msg.sender, address(this), amount);

        // Deposit to Aave immediately
        _depositToAave(amount);

        // Create lender order
        orderId = nextLenderOrderId++;
        uint8 rateBucket = DataTypes.getRateBucket(minRateBps);

        lenderOrders[orderId] = DataTypes.LenderOrder({
            owner: msg.sender,
            amount: amount,
            remaining: amount,
            minRateBps: minRateBps,
            term: term,
            createdAt: uint32(block.timestamp),
            rateBucket: rateBucket
        });

        // Add to queue
        lenderQueue.enqueue(rateBucket, term, orderId);

        emit LenderDeposit(orderId, msg.sender, amount, minRateBps, term);
    }

    /**
     * @notice Borrower requests a loan with collateral
     * @param amount Amount to borrow
     * @param maxRateBps Maximum acceptable rate in basis points
     * @param term Term bucket (0=7d, 1=30d, 2=90d)
     * @param collateralAmount Collateral amount (must meet LTV requirements)
     */
    function requestBorrow(uint96 amount, uint16 maxRateBps, uint8 term, uint96 collateralAmount)
        external
        nonReentrant
        returns (uint256 orderId)
    {
        if (amount == 0) revert InvalidAmount();
        if (term > 2) revert InvalidTerm();
        if (maxRateBps > 10000) revert InvalidRate();

        // Check collateral requirement (LTV = 75%)
        uint256 requiredCollateral = (uint256(amount) * 10000) / DataTypes.LTV_BPS;
        if (collateralAmount < requiredCollateral) revert InsufficientCollateral();

        // Transfer collateral from borrower
        underlyingAsset.transferFrom(msg.sender, address(this), collateralAmount);

        // Create borrow order
        orderId = nextBorrowOrderId++;
        uint8 rateBucket = DataTypes.getRateBucket(maxRateBps);

        borrowOrders[orderId] = DataTypes.BorrowOrder({
            owner: msg.sender,
            amount: amount,
            remaining: amount,
            maxRateBps: maxRateBps,
            term: term,
            createdAt: uint32(block.timestamp),
            rateBucket: rateBucket,
            collateralAmount: collateralAmount
        });

        // Add to queue
        borrowQueue.enqueue(rateBucket, term, orderId);

        emit BorrowRequest(orderId, msg.sender, amount, maxRateBps, term, collateralAmount);
    }

    /**
     * @notice Match lender and borrower orders
     * @param maxItems Maximum number of matches to process (gas limit)
     * @return matchCount Number of matches made
     */
    function matchOrders(uint256 maxItems) external nonReentrant returns (uint256 matchCount) {
        uint256 gasStart = gasleft();

        // Try to match across all term buckets
        for (uint8 term = 0; term < 3; term++) {
            matchCount += _matchForTerm(term, maxItems - matchCount);
            if (matchCount >= maxItems) break;
        }

        if (matchCount == 0) revert NoMatchesFound();

        // Reward keeper (1% of total interest estimated)
        _rewardKeeper(msg.sender, gasStart);
    }

    /**
     * @notice Internal function to match orders for a specific term
     * @param term Term bucket to match
     * @param maxItems Maximum matches
     * @return matchCount Matches made
     */
    function _matchForTerm(uint8 term, uint256 maxItems) internal returns (uint256 matchCount) {
        for (uint256 i = 0; i < maxItems; i++) {
            // Get lowest lender rate and highest borrow rate
            uint8 lenderBucket = lenderQueue.getLowestNonEmptyBucket(term);
            uint8 borrowBucket = borrowQueue.getHighestNonEmptyBucket(term);

            // Check if match is possible
            if (lenderBucket == type(uint8).max || borrowBucket == type(uint8).max) break;

            uint256 lenderOrderId = lenderQueue.peek(lenderBucket, term);
            uint256 borrowOrderId = borrowQueue.peek(borrowBucket, term);

            DataTypes.LenderOrder storage lenderOrder = lenderOrders[lenderOrderId];
            DataTypes.BorrowOrder storage borrowOrder = borrowOrders[borrowOrderId];

            // Check if rates match (minRate <= maxRate)
            if (lenderOrder.minRateBps > borrowOrder.maxRateBps) break;

            // Calculate match amount (partial fill allowed)
            uint96 matchAmount = lenderOrder.remaining < borrowOrder.remaining
                ? lenderOrder.remaining
                : borrowOrder.remaining;

            // Calculate agreed rate (average of min and max)
            uint16 agreedRate = (lenderOrder.minRateBps + borrowOrder.maxRateBps) / 2;

            // Calculate collateral to lock
            uint96 collateralToLock = uint96((uint256(matchAmount) * 10000) / DataTypes.LTV_BPS);

            // Withdraw matched amount from Aave
            _withdrawFromAave(matchAmount);

            // Transfer to borrower
            underlyingAsset.transfer(borrowOrder.owner, matchAmount);
            // Create loan position
            uint256 loanId = nextLoanId++;
            loans[loanId] = DataTypes.LoanPosition({
                lender: lenderOrder.owner,
                borrower: borrowOrder.owner,
                principal: matchAmount,
                rateBps: agreedRate,
                term: term,
                startTime: uint32(block.timestamp),
                collateralAmount: collateralToLock,
                repaid: false
            });

            // Update remaining amounts - use temporary variables to avoid storage issues
            uint96 newLenderRemaining = lenderOrder.remaining - matchAmount;
            uint96 newBorrowRemaining = borrowOrder.remaining - matchAmount;
            uint96 newBorrowCollateral = borrowOrder.collateralAmount - collateralToLock;

            lenderOrder.remaining = newLenderRemaining;
            borrowOrder.remaining = newBorrowRemaining;
            borrowOrder.collateralAmount = newBorrowCollateral;

            // Remove from queue if fully filled
            if (lenderOrder.remaining == 0) {
                lenderQueue.dequeue(lenderBucket, term);
            }
            if (borrowOrder.remaining == 0) {
                borrowQueue.dequeue(borrowBucket, term);

                // Return excess collateral if any
                if (borrowOrder.collateralAmount > 0) {
                    userBalances[borrowOrder.owner] += borrowOrder.collateralAmount;
                }
            }

            emit Matched(loanId, lenderOrderId, borrowOrderId, lenderOrder.owner, borrowOrder.owner, matchAmount, agreedRate, term);
            matchCount++;
        }
    }

    /**
     * @notice Borrower repays loan with interest
     * @param loanId Loan ID to repay
     */
    function repayLoan(uint256 loanId) external nonReentrant {
        DataTypes.LoanPosition storage loan = loans[loanId];

        if (loan.principal == 0) revert LoanNotFound();
        if (loan.borrower != msg.sender) revert NotBorrower();
        if (loan.repaid) revert AlreadyRepaid();

        // Calculate interest
        uint256 duration = block.timestamp - loan.startTime;
        uint256 interest = (uint256(loan.principal) * loan.rateBps * duration) / (365 days * 10000);
        uint96 totalRepayment = loan.principal + uint96(interest);

        // Transfer repayment from borrower
        underlyingAsset.transferFrom(msg.sender, address(this), totalRepayment);

        // Mark as repaid
        loan.repaid = true;

        // Credit lender balance (principal + interest)
        uint96 keeperFee = uint96((interest * KEEPER_REWARD_BPS) / 10000);
        keeperRewardPool += keeperFee;
        userBalances[loan.lender] += totalRepayment - keeperFee;

        // Return collateral to borrower
        userBalances[loan.borrower] += loan.collateralAmount;

        emit Repaid(loanId, msg.sender, loan.principal, uint96(interest));
    }

    /**
     * @notice Liquidate undercollateralized loan
     * @param loanId Loan ID to liquidate
     */
    function liquidate(uint256 loanId) external nonReentrant {
        DataTypes.LoanPosition storage loan = loans[loanId];

        if (loan.principal == 0) revert LoanNotFound();
        if (loan.repaid) revert AlreadyRepaid();

        // Check if loan is undercollateralized or past due
        uint256 termDuration = DataTypes.getTermDuration(loan.term);
        bool pastDue = block.timestamp > loan.startTime + termDuration;

        // Calculate current debt with interest
        uint256 duration = block.timestamp - loan.startTime;
        uint256 interest = (uint256(loan.principal) * loan.rateBps * duration) / (365 days * 10000);
        uint256 currentDebt = loan.principal + interest;

        // Check LTV (simplified - using 1:1 price)
        uint256 currentLTV = (currentDebt * 10000) / loan.collateralAmount;
        bool undercollateralized = currentLTV > DataTypes.LIQUIDATION_LTV_BPS;

        if (!pastDue && !undercollateralized) revert Undercollateralized();

        // Mark as repaid (liquidated)
        loan.repaid = true;

        // Credit lender with collateral
        userBalances[loan.lender] += loan.collateralAmount;

        // Liquidator gets 5% of collateral as reward
        uint96 liquidatorReward = loan.collateralAmount / 20; // 5%
        if (liquidatorReward > 0) {
            userBalances[loan.lender] -= liquidatorReward;
            userBalances[msg.sender] += liquidatorReward;
        }

        emit Liquidated(loanId, msg.sender, loan.collateralAmount);
    }

    /**
     * @notice Withdraw available balance
     */
    function withdraw() external nonReentrant {
        uint96 balance = userBalances[msg.sender];
        if (balance == 0) revert InvalidAmount();

        userBalances[msg.sender] = 0;
        underlyingAsset.transfer(msg.sender, balance);

        emit Withdrawn(msg.sender, balance);
    }

    /**
     * @notice Cancel unmatched lender order
     * @param orderId Order ID to cancel
     */
    function cancelLenderOrder(uint256 orderId) external nonReentrant {
        DataTypes.LenderOrder storage order = lenderOrders[orderId];

        if (order.owner != msg.sender) revert NotLender();
        if (order.remaining == 0) revert InvalidAmount();

        uint96 amount = order.remaining;
        order.remaining = 0;

        // Withdraw from Aave
        uint256 withdrawn = _withdrawFromAave(amount);

        // Credit user balance
        userBalances[msg.sender] += uint96(withdrawn);

        emit LenderCancelled(orderId, msg.sender, uint96(withdrawn));
    }

    /**
     * @notice Cancel unmatched borrow order
     * @param orderId Order ID to cancel
     */
    function cancelBorrowOrder(uint256 orderId) external nonReentrant {
        DataTypes.BorrowOrder storage order = borrowOrders[orderId];

        if (order.owner != msg.sender) revert NotBorrower();
        if (order.remaining == 0) revert InvalidAmount();

        uint96 collateral = order.collateralAmount;
        order.remaining = 0;
        order.collateralAmount = 0;

        // Return collateral
        userBalances[msg.sender] += collateral;

        emit BorrowerCancelled(orderId, msg.sender, collateral);
    }

    /**
     * @notice Reward keeper for running matchOrders
     * @param keeper Keeper address
     * @param gasStart Gas at start of transaction
     */
    function _rewardKeeper(address keeper, uint256 gasStart) internal {
        if (keeperRewardPool < MIN_KEEPER_REWARD) return;

        // Calculate gas used and reward keeper
        uint256 gasUsed = gasStart - gasleft();
        uint96 reward = uint96(gasUsed * tx.gasprice / 1e12); // Convert to USDC (6 decimals)

        // Cap reward at available pool
        if (reward > keeperRewardPool) {
            reward = keeperRewardPool;
        }

        if (reward > 0) {
            keeperRewardPool -= reward;
            userBalances[keeper] += reward;
            emit KeeperRewarded(keeper, reward);
        }
    }

    /**
     * @notice Get Aave balance
     */
    function getAaveBalance() external view returns (uint256) {
        return _getAaveBalance();
    }

    /**
     * @notice Get user's withdrawable balance
     */
    function getWithdrawableBalance(address user) external view returns (uint96) {
        return userBalances[user];
    }
}
