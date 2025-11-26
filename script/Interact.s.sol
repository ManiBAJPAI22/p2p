// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {LendingMatchingEngine} from "../src/LendingMatchingEngine.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/**
 * @title Interact
 * @notice Helper script to interact with deployed LendingMatchingEngine
 * @dev Run with: forge script script/Interact.s.sol:InteractScript --rpc-url sepolia --broadcast
 */
contract InteractScript is Script {
    // Deployed contract address on Sepolia
    address constant ENGINE = 0x622728dECdf3D473F40548da26688A24b4bED2AA;
    address constant LINK = 0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address sender = vm.addr(privateKey);

        console2.log("Interacting as:", sender);
        console2.log("LendingMatchingEngine:", ENGINE);

        vm.startBroadcast(privateKey);

        // Example: Check your balance
        checkBalance(sender);

        // Example: Deposit as lender (uncomment to use)
        // depositAsLender(1000e18, 500, 0); // 1000 LINK, 5% APR, 7 days

        // Example: Request borrow (uncomment to use)
        // requestAsBorrower(1000e18, 600, 0, 1333e18); // 1000 LINK, 6% APR, 7 days, 1333 collateral

        // Example: Match orders as keeper (uncomment to use)
        // matchAsKeeper(10);

        // Example: Withdraw (uncomment to use)
        // withdrawFunds();

        vm.stopBroadcast();
    }

    function checkBalance(address user) internal view {
        LendingMatchingEngine engine = LendingMatchingEngine(ENGINE);
        uint96 balance = engine.getWithdrawableBalance(user);
        uint256 aaveBalance = engine.getAaveBalance();

        console2.log("Your withdrawable balance:", balance);
        console2.log("Total in Aave:", aaveBalance);
    }

    function depositAsLender(uint96 amount, uint16 minRateBps, uint8 term) internal {
        IERC20 link = IERC20(LINK);
        LendingMatchingEngine engine = LendingMatchingEngine(ENGINE);

        // Approve
        link.approve(ENGINE, amount);

        // Deposit
        uint256 orderId = engine.depositLender(amount, minRateBps, term);

        console2.log("Lender order created:", orderId);
        console2.log("Amount:", amount);
        console2.log("Min rate:", minRateBps, "bps");
        console2.log("Term:", term);
    }

    function requestAsBorrower(uint96 amount, uint16 maxRateBps, uint8 term, uint96 collateral) internal {
        IERC20 link = IERC20(LINK);
        LendingMatchingEngine engine = LendingMatchingEngine(ENGINE);

        // Approve collateral
        link.approve(ENGINE, collateral);

        // Request borrow
        uint256 orderId = engine.requestBorrow(amount, maxRateBps, term, collateral);

        console2.log("Borrow order created:", orderId);
        console2.log("Amount:", amount);
        console2.log("Max rate:", maxRateBps, "bps");
        console2.log("Term:", term);
        console2.log("Collateral:", collateral);
    }

    function matchAsKeeper(uint256 maxItems) internal {
        LendingMatchingEngine engine = LendingMatchingEngine(ENGINE);

        uint256 matches = engine.matchOrders(maxItems);

        console2.log("Matches made:", matches);
    }

    function withdrawFunds() internal {
        LendingMatchingEngine engine = LendingMatchingEngine(ENGINE);

        engine.withdraw();

        console2.log("Withdrawal successful");
    }

    function repayLoan(uint256 loanId) internal {
        IERC20 link = IERC20(LINK);
        LendingMatchingEngine engine = LendingMatchingEngine(ENGINE);

        // Approve large amount for principal + interest
        link.approve(ENGINE, type(uint256).max);

        // Repay
        engine.repayLoan(loanId);

        console2.log("Loan repaid:", loanId);
    }
}
