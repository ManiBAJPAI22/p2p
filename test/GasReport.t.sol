// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {LendingMatchingEngine} from "../src/LendingMatchingEngine.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract GasReportTest is Test {
    LendingMatchingEngine public engine;

    address constant AAVE_POOL = address(0x1);
    address constant USDC = address(0x2);
    address constant AUSDC = address(0x3);

    function setUp() public {
        // Deploy with mock addresses for gas testing
        engine = new LendingMatchingEngine(AAVE_POOL, USDC, AUSDC);
    }

    function testGasDeployment() public view {
        // Deployment gas is captured automatically
        assert(address(engine) != address(0));
    }
}
