// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {LendingMatchingEngine} from "../src/LendingMatchingEngine.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract DebugMatchTest is Test {
    LendingMatchingEngine engine;

    // Sepolia addresses
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address constant LINK = 0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5;
    address constant ALINK = 0x3FfAf50D4F4E96eB78f2407c090b72e86eCaed24;

    address lender = address(0x1);
    address borrower = address(0x2);

    function setUp() public {
        // Fork Sepolia
        vm.createSelectFork("https://eth-sepolia.g.alchemy.com/v2/K92udouYRthtCsWJjsPNzw8zjkxicNXg");

        // Deploy engine
        engine = new LendingMatchingEngine(AAVE_POOL, LINK, ALINK);

        // Give lender and borrower some LINK
        deal(LINK, lender, 10000e18);
        deal(LINK, borrower, 10000e18);
    }

    function testMatchOrdersDebug() public {
        console2.log("=== Testing Match Orders ===");

        // Lender deposits 1000 LINK at 5% APR
        vm.startPrank(lender);
        IERC20(LINK).approve(address(engine), 1000e18);
        uint256 lenderOrderId = engine.depositLender(uint96(1000e18), 500, 0);
        console2.log("Lender order created:", lenderOrderId);
        vm.stopPrank();

        // Borrower requests 500 LINK at 6% max APR with 667 LINK collateral
        vm.startPrank(borrower);
        IERC20(LINK).approve(address(engine), 667e18);
        uint256 borrowOrderId = engine.requestBorrow(uint96(500e18), 600, 0, uint96(667e18));
        console2.log("Borrow order created:", borrowOrderId);
        vm.stopPrank();

        // Check orders
        (address lenderOwner, uint96 lenderAmount, uint96 lenderRemaining,,,,) = engine.lenderOrders(lenderOrderId);
        console2.log("Lender order:");
        console2.log("  Owner:", lenderOwner);
        console2.log("  Amount:", lenderAmount);
        console2.log("  Remaining:", lenderRemaining);

        (address borrowOwner, uint96 borrowAmount, uint96 borrowRemaining,,,,,uint96 collateral) = engine.borrowOrders(borrowOrderId);
        console2.log("Borrow order:");
        console2.log("  Owner:", borrowOwner);
        console2.log("  Amount:", borrowAmount);
        console2.log("  Remaining:", borrowRemaining);
        console2.log("  Collateral:", collateral);

        // Try to match
        console2.log("\n=== Attempting to match ===");
        uint256 matches = engine.matchOrders(10);
        console2.log("Matches made:", matches);
    }
}
