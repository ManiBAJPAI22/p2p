// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {LendingMatchingEngine} from "../src/LendingMatchingEngine.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract FreshDeployTest is Test {
    LendingMatchingEngine engine;
    IERC20 link;

    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address constant LINK = 0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5;
    address constant ALINK = 0x3FfAf50D4F4E96eB78f2407c090b72e86eCaed24;

    address lender = address(0x1);
    address borrower = address(0x2);

    function setUp() public {
        vm.createSelectFork("https://ethereum-sepolia-rpc.publicnode.com");

        // Deploy fresh contract with fixed code
        engine = new LendingMatchingEngine(AAVE_POOL, LINK, ALINK);
        link = IERC20(LINK);

        console2.log("Fresh engine deployed at:", address(engine));

        // Fund accounts
        deal(address(link), lender, 100 ether);
        deal(address(link), borrower, 100 ether);
    }

    function testMatchingWorksWithFreshDeploy() public {
        console2.log("=== Testing Fresh Deployment with BOTH Fixes ===");

        // Lender deposits 5 LINK at 5 bps (0.05%) min rate
        vm.startPrank(lender);
        link.approve(address(engine), 5 ether);
        uint256 lenderOrderId = engine.depositLender(5 ether, 5, 0);
        vm.stopPrank();
        console2.log("Lender order created:", lenderOrderId);

        // Borrower requests 5 LINK at 5 bps (0.05%) max rate with 6.67 LINK collateral
        vm.startPrank(borrower);
        link.approve(address(engine), 6.67 ether);
        uint256 borrowOrderId = engine.requestBorrow(5 ether, 5, 0, 6.67 ether);
        vm.stopPrank();
        console2.log("Borrower order created:", borrowOrderId);

        // Match orders
        address keeper = address(0x3);
        vm.prank(keeper);
        uint256 matches = engine.matchOrders(10);

        console2.log("Matches made:", matches);
        assertEq(matches, 1, "Should have matched 1 order");

        // Check borrower received the loan
        uint256 borrowerBalance = link.balanceOf(borrower);
        console2.log("Borrower balance after match:", borrowerBalance);
        assertGt(borrowerBalance, 93 ether, "Borrower should have received loan");

        console2.log("SUCCESS! Matching works with both fixes applied!");
    }
}
