// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

interface IAToken is IERC20 {
    /**
     * @notice Returns the scaled balance of the user
     * @param user The address of the user
     * @return The scaled balance of the user
     */
    function scaledBalanceOf(address user) external view returns (uint256);
}
