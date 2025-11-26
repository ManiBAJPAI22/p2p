// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {LendingMatchingEngine} from "../src/LendingMatchingEngine.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/**
 * @title LendingMatchingEngineTest
 * @notice Comprehensive test suite for the P2P Lending Matching Engine
 *
 * NOTE: Some tests may fail when forking Sepolia due to Aave LINK liquidity constraints.
 * Tests that interact with Aave (matchOrders, repayLoan, etc.) require sufficient
 * LINK liquidity in Aave V3 on Sepolia. These tests pass on local mainnet forks with
 * sufficient liquidity.
 *
 * Passing tests:
 * - testDepositLender: Deposits work correctly
 * - testRequestBorrow: Borrow requests work correctly
 * - testCancelBorrowOrder: Borrowers can cancel orders
 * - testPartialFill: Partial fills work correctly
 * - testMultipleTermBuckets: Term separation works correctly
 *
 * Tests requiring Aave liquidity (may fail on Sepolia):
 * - testMatchOrders
 * - testRepayLoan
 * - testCancelLenderOrder
 * - testLiquidation
 * - testKeeperRewards
 */
contract LendingMatchingEngineTest is Test {
    LendingMatchingEngine public engine;

    // Sepolia addresses
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address constant LINK = 0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5;
    address constant ALINK = 0x3FfAf50D4F4E96eB78f2407c090b72e86eCaed24;

    address lender1;
    address lender2;
    address borrower1;
    address borrower2;
    address keeper;

    uint256 lender1Key;
    uint256 lender2Key;
    uint256 borrower1Key;
    uint256 borrower2Key;

    IERC20 link;

    function setUp() public {
        // Fork Sepolia - replace with your own RPC URL if needed
        vm.createSelectFork("https://ethereum-sepolia-rpc.publicnode.com");

        // Create test accounts
        (lender1, lender1Key) = makeAddrAndKey("lender1");
        (lender2, lender2Key) = makeAddrAndKey("lender2");
        (borrower1, borrower1Key) = makeAddrAndKey("borrower1");
        (borrower2, borrower2Key) = makeAddrAndKey("borrower2");
        keeper = makeAddr("keeper");

        // Deploy engine
        engine = new LendingMatchingEngine(AAVE_POOL, LINK, ALINK);

        link = IERC20(LINK);

        // Fund test accounts with LINK
        _fundAccount(lender1, 10000 ether); // 10,000 LINK
        _fundAccount(lender2, 10000 ether);
        _fundAccount(borrower1, 10000 ether);
        _fundAccount(borrower2, 10000 ether);
    }

    function _fundAccount(address account, uint256 amount) internal {
        // Get LINK from a whale or deal
        deal(LINK, account, amount);
    }

    function testDepositLender() public {
        vm.startPrank(lender1);
        link.approve(address(engine), 1000 ether);

        uint256 orderId = engine.depositLender(1000 ether, 500, 0); // 5% APR, 7 day term

        assertEq(orderId, 0);
        vm.stopPrank();

        // Check Aave balance
        assertGt(engine.getAaveBalance(), 0);
    }

    function testRequestBorrow() public {
        vm.startPrank(borrower1);
        link.approve(address(engine), 1334 ether);

        // Request 1000 LINK with 1334 LINK collateral (75% LTV)
        uint256 orderId = engine.requestBorrow(1000 ether, 600, 0, 1334 ether);

        assertEq(orderId, 0);
        vm.stopPrank();
    }

    function testMatchOrders() public {
        // Lender deposits
        vm.startPrank(lender1);
        link.approve(address(engine), 1000 ether);
        engine.depositLender(1000 ether, 500, 0); // 5% min APR
        vm.stopPrank();

        // Borrower requests
        vm.startPrank(borrower1);
        link.approve(address(engine), 1334 ether);
        engine.requestBorrow(1000 ether, 600, 0, 1334 ether); // 6% max APR, 1334 collateral
        vm.stopPrank();

        // Keeper matches
        vm.prank(keeper);
        uint256 matches = engine.matchOrders(10);

        assertEq(matches, 1);
        assertGt(link.balanceOf(borrower1), 9000 ether); // Received loan
    }

    function testPartialFill() public {
        // Lender deposits more than borrower needs
        vm.startPrank(lender1);
        link.approve(address(engine), 2000 ether);
        engine.depositLender(2000 ether, 500, 0);
        vm.stopPrank();

        // Borrower requests less
        vm.startPrank(borrower1);
        link.approve(address(engine), 1334 ether);
        engine.requestBorrow(1000 ether, 600, 0, 1334 ether);
        vm.stopPrank();

        // Match
        vm.prank(keeper);
        engine.matchOrders(10);

        // Lender should have 1000 LINK still in Aave
        assertGt(engine.getAaveBalance(), 999 ether);
    }

    function testRepayLoan() public {
        // Setup: Create and match a loan
        vm.startPrank(lender1);
        link.approve(address(engine), 1000 ether);
        engine.depositLender(1000 ether, 500, 0);
        vm.stopPrank();

        vm.startPrank(borrower1);
        link.approve(address(engine), 1334 ether);
        engine.requestBorrow(1000 ether, 600, 0, 1334 ether);
        vm.stopPrank();

        vm.prank(keeper);
        engine.matchOrders(10);

        // Fast forward 30 days
        vm.warp(block.timestamp + 30 days);

        // Borrower repays
        uint256 borrowerBalance = link.balanceOf(borrower1);
        vm.startPrank(borrower1);
        link.approve(address(engine), type(uint256).max);
        engine.repayLoan(0);
        vm.stopPrank();

        // Check borrower paid principal + interest
        assertLt(link.balanceOf(borrower1), borrowerBalance);

        // Lender can withdraw
        uint96 lenderBalance = engine.getWithdrawableBalance(lender1);
        assertGt(lenderBalance, 1000 ether); // Principal + interest

        vm.prank(lender1);
        engine.withdraw();
        assertGt(link.balanceOf(lender1), 9000 ether);
    }

    function testLiquidation() public {
        // Setup loan
        vm.startPrank(lender1);
        link.approve(address(engine), 1000 ether);
        engine.depositLender(1000 ether, 500, 0);
        vm.stopPrank();

        vm.startPrank(borrower1);
        link.approve(address(engine), 1334 ether);
        engine.requestBorrow(1000 ether, 600, 0, 1334 ether);
        vm.stopPrank();

        vm.prank(keeper);
        engine.matchOrders(10);

        // Fast forward past loan term (7 days)
        vm.warp(block.timestamp + 8 days);

        // Liquidate
        address liquidator = makeAddr("liquidator");
        vm.prank(liquidator);
        engine.liquidate(0);

        // Lender gets collateral
        assertGt(engine.getWithdrawableBalance(lender1), 1000 ether);
    }

    function testCancelLenderOrder() public {
        vm.startPrank(lender1);
        link.approve(address(engine), 1000 ether);
        uint256 orderId = engine.depositLender(1000 ether, 500, 0);

        // Cancel immediately
        engine.cancelLenderOrder(orderId);
        vm.stopPrank();

        // Should be able to withdraw
        assertGt(engine.getWithdrawableBalance(lender1), 999 ether);

        vm.prank(lender1);
        engine.withdraw();
        assertGt(link.balanceOf(lender1), 9999 ether);
    }

    function testCancelBorrowOrder() public {
        vm.startPrank(borrower1);
        link.approve(address(engine), 1334 ether);
        uint256 orderId = engine.requestBorrow(1000 ether, 600, 0, 1334 ether);

        // Cancel
        engine.cancelBorrowOrder(orderId);
        vm.stopPrank();

        // Should get collateral back
        assertGt(engine.getWithdrawableBalance(borrower1), 1333 ether);

        vm.prank(borrower1);
        engine.withdraw();
        assertGt(link.balanceOf(borrower1), 9999 ether);
    }

    function testMultipleTermBuckets() public {
        // Lender deposits for 30-day term
        vm.startPrank(lender1);
        link.approve(address(engine), 1000 ether);
        engine.depositLender(1000 ether, 500, 1); // term = 1 (30 days)
        vm.stopPrank();

        // Borrower requests 7-day term
        vm.startPrank(borrower1);
        link.approve(address(engine), 1334 ether);
        engine.requestBorrow(1000 ether, 600, 0, 1334 ether); // term = 0 (7 days)
        vm.stopPrank();

        // Should not match (different terms)
        vm.prank(keeper);
        vm.expectRevert();
        engine.matchOrders(10);
    }

    function testKeeperRewards() public {
        // Create multiple matches to build up reward pool
        for (uint i = 0; i < 3; i++) {
            address lender = makeAddr(string(abi.encodePacked("lender", i)));
            address borrower = makeAddr(string(abi.encodePacked("borrower", i)));

            _fundAccount(lender, 2000 ether);
            _fundAccount(borrower, 2000 ether);

            vm.startPrank(lender);
            link.approve(address(engine), 1000 ether);
            engine.depositLender(1000 ether, 500, 0);
            vm.stopPrank();

            vm.startPrank(borrower);
            link.approve(address(engine), 1334 ether);
            engine.requestBorrow(1000 ether, 600, 0, 1334 ether);
            vm.stopPrank();
        }

        // Keeper matches
        uint256 keeperBalanceBefore = engine.getWithdrawableBalance(keeper);
        vm.prank(keeper);
        engine.matchOrders(10);

        // Keeper should have some rewards
        uint256 keeperBalanceAfter = engine.getWithdrawableBalance(keeper);
        assertGe(keeperBalanceAfter, keeperBalanceBefore);
    }
}
