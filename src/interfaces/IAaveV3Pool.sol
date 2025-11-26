// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAaveV3Pool {
    /**
     * @notice Supplies an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
     * @param asset The address of the underlying asset to supply
     * @param amount The amount to be supplied
     * @param onBehalfOf The address that will receive the aTokens
     * @param referralCode Code used to register the integrator originating the operation
     */
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    /**
     * @notice Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
     * @param asset The address of the underlying asset to withdraw
     * @param amount The underlying amount to be withdrawn
     * @param to The address that will receive the underlying
     * @return The final amount withdrawn
     */
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}
