// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IAaveV3Pool} from "./interfaces/IAaveV3Pool.sol";
import {IAToken} from "./interfaces/IAToken.sol";

/**
 * @title AaveConnector
 * @notice Handles all Aave V3 interactions for depositing and withdrawing unmatched liquidity
 * @dev Caches pool and aToken references for gas efficiency
 */
contract AaveConnector {
    // Custom errors
    error DepositFailed();
    error WithdrawFailed();
    error InsufficientBalance();

    // Immutable storage for gas efficiency
    IAaveV3Pool public immutable aavePool;
    IERC20 public immutable underlyingAsset;
    IAToken public immutable aToken;

    /**
     * @notice Constructor
     * @param _aavePool Aave V3 Pool address
     * @param _underlyingAsset Underlying asset (e.g., USDC)
     * @param _aToken aToken address (e.g., aUSDC)
     */
    constructor(address _aavePool, address _underlyingAsset, address _aToken) {
        aavePool = IAaveV3Pool(_aavePool);
        underlyingAsset = IERC20(_underlyingAsset);
        aToken = IAToken(_aToken);
    }

    /**
     * @notice Deposit underlying asset to Aave
     * @param amount Amount to deposit
     */
    function _depositToAave(uint256 amount) internal {
        if (amount == 0) return;

        // Approve Aave pool to spend tokens
        underlyingAsset.approve(address(aavePool), amount);

        // Supply to Aave (receive aTokens)
        aavePool.supply(address(underlyingAsset), amount, address(this), 0);
    }

    /**
     * @notice Withdraw underlying asset from Aave
     * @param amount Amount to withdraw
     * @return actualAmount Actual amount withdrawn
     */
    function _withdrawFromAave(uint256 amount) internal returns (uint256 actualAmount) {
        if (amount == 0) return 0;

        // Check aToken balance
        uint256 aTokenBalance = aToken.balanceOf(address(this));
        if (aTokenBalance == 0) revert InsufficientBalance();

        // Withdraw from Aave (burn aTokens, receive underlying)
        actualAmount = aavePool.withdraw(address(underlyingAsset), amount, address(this));
    }

    /**
     * @notice Get the total balance in Aave (including accrued yield)
     * @return Total underlying balance
     */
    function _getAaveBalance() internal view returns (uint256) {
        return aToken.balanceOf(address(this));
    }
}
