// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {LendingMatchingEngine} from "../src/LendingMatchingEngine.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract LendingMatchingEngineTest is Test {
    LendingMatchingEngine public engine;

    // Sepolia addresses
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address constant USDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
    address constant AUSDC = 0x16dA4541aD1807f4443d92D26044C1147406EB80;

    address lender1;
    address lender2;
    address borrower1;
    address borrower2;
    address keeper;

    uint256 lender1Key;
    uint256 lender2Key;
    uint256 borrower1Key;
    uint256 borrower2Key;

    IERC20 usdc;

    function setUp() public {
        // Fork Sepolia
        vm.createSelectFork("https://sepolia.infura.io/v3/YOUR_INFURA_KEY");

        // Create test accounts
        (lender1, lender1Key) = makeAddrAndKey("lender1");
        (lender2, lender2Key) = makeAddrAndKey("lender2");
        (borrower1, borrower1Key) = makeAddrAndKey("borrower1");
        (borrower2, borrower2Key) = makeAddrAndKey("borrower2");
        keeper = makeAddr("keeper");

        // Deploy engine
        engine = new LendingMatchingEngine(AAVE_POOL, USDC, AUSDC);

        usdc = IERC20(USDC);

        // Fund test accounts with USDC
        _fundAccount(lender1, 10000e6); // 10,000 USDC
        _fundAccount(lender2, 10000e6);
        _fundAccount(borrower1, 10000e6);
        _fundAccount(borrower2, 10000e6);
    }

    function _fundAccount(address account, uint256 amount) internal {
        // Get USDC from a whale or deal
        deal(USDC, account, amount);
    }

    function testDepositLender() public {
        vm.startPrank(lender1);
        usdc.approve(address(engine), 1000e6);

        uint256 orderId = engine.depositLender(1000e6, 500, 0); // 5% APR, 7 day term

        assertEq(orderId, 0);
        vm.stopPrank();

        // Check Aave balance
        assertGt(engine.getAaveBalance(), 0);
    }

    function testRequestBorrow() public {
        vm.startPrank(borrower1);
        usdc.approve(address(engine), 2000e6);

        // Request 1000 USDC with 1333 USDC collateral (75% LTV)
        uint256 orderId = engine.requestBorrow(1000e6, 600, 0, 1333e6);

        assertEq(orderId, 0);
        vm.stopPrank();
    }

    function testMatchOrders() public {
        // Lender deposits
        vm.startPrank(lender1);
        usdc.approve(address(engine), 1000e6);
        engine.depositLender(1000e6, 500, 0); // 5% min APR
        vm.stopPrank();

        // Borrower requests
        vm.startPrank(borrower1);
        usdc.approve(address(engine), 2000e6);
        engine.requestBorrow(1000e6, 600, 0, 1333e6); // 6% max APR, 1333 collateral
        vm.stopPrank();

        // Keeper matches
        vm.prank(keeper);
        uint256 matches = engine.matchOrders(10);

        assertEq(matches, 1);
        assertGt(usdc.balanceOf(borrower1), 9000e6); // Received loan
    }

    function testPartialFill() public {
        // Lender deposits more than borrower needs
        vm.startPrank(lender1);
        usdc.approve(address(engine), 2000e6);
        engine.depositLender(2000e6, 500, 0);
        vm.stopPrank();

        // Borrower requests less
        vm.startPrank(borrower1);
        usdc.approve(address(engine), 1500e6);
        engine.requestBorrow(1000e6, 600, 0, 1333e6);
        vm.stopPrank();

        // Match
        vm.prank(keeper);
        engine.matchOrders(10);

        // Lender should have 1000 USDC still in Aave
        assertGt(engine.getAaveBalance(), 999e6);
    }

    function testRepayLoan() public {
        // Setup: Create and match a loan
        vm.startPrank(lender1);
        usdc.approve(address(engine), 1000e6);
        engine.depositLender(1000e6, 500, 0);
        vm.stopPrank();

        vm.startPrank(borrower1);
        usdc.approve(address(engine), 2000e6);
        engine.requestBorrow(1000e6, 600, 0, 1333e6);
        vm.stopPrank();

        vm.prank(keeper);
        engine.matchOrders(10);

        // Fast forward 30 days
        vm.warp(block.timestamp + 30 days);

        // Borrower repays
        uint256 borrowerBalance = usdc.balanceOf(borrower1);
        vm.startPrank(borrower1);
        usdc.approve(address(engine), type(uint256).max);
        engine.repayLoan(0);
        vm.stopPrank();

        // Check borrower paid principal + interest
        assertLt(usdc.balanceOf(borrower1), borrowerBalance);

        // Lender can withdraw
        uint96 lenderBalance = engine.getWithdrawableBalance(lender1);
        assertGt(lenderBalance, 1000e6); // Principal + interest

        vm.prank(lender1);
        engine.withdraw();
        assertGt(usdc.balanceOf(lender1), 9000e6);
    }

    function testLiquidation() public {
        // Setup loan
        vm.startPrank(lender1);
        usdc.approve(address(engine), 1000e6);
        engine.depositLender(1000e6, 500, 0);
        vm.stopPrank();

        vm.startPrank(borrower1);
        usdc.approve(address(engine), 2000e6);
        engine.requestBorrow(1000e6, 600, 0, 1333e6);
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
        assertGt(engine.getWithdrawableBalance(lender1), 1000e6);
    }

    function testCancelLenderOrder() public {
        vm.startPrank(lender1);
        usdc.approve(address(engine), 1000e6);
        uint256 orderId = engine.depositLender(1000e6, 500, 0);

        // Cancel immediately
        engine.cancelLenderOrder(orderId);
        vm.stopPrank();

        // Should be able to withdraw
        assertGt(engine.getWithdrawableBalance(lender1), 999e6);

        vm.prank(lender1);
        engine.withdraw();
        assertGt(usdc.balanceOf(lender1), 9999e6);
    }

    function testCancelBorrowOrder() public {
        vm.startPrank(borrower1);
        usdc.approve(address(engine), 1333e6);
        uint256 orderId = engine.requestBorrow(1000e6, 600, 0, 1333e6);

        // Cancel
        engine.cancelBorrowOrder(orderId);
        vm.stopPrank();

        // Should get collateral back
        assertGt(engine.getWithdrawableBalance(borrower1), 1332e6);

        vm.prank(borrower1);
        engine.withdraw();
        assertGt(usdc.balanceOf(borrower1), 9999e6);
    }

    function testMultipleTermBuckets() public {
        // Lender deposits for 30-day term
        vm.startPrank(lender1);
        usdc.approve(address(engine), 1000e6);
        engine.depositLender(1000e6, 500, 1); // term = 1 (30 days)
        vm.stopPrank();

        // Borrower requests 7-day term
        vm.startPrank(borrower1);
        usdc.approve(address(engine), 1333e6);
        engine.requestBorrow(1000e6, 600, 0, 1333e6); // term = 0 (7 days)
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

            _fundAccount(lender, 2000e6);
            _fundAccount(borrower, 2000e6);

            vm.startPrank(lender);
            usdc.approve(address(engine), 1000e6);
            engine.depositLender(1000e6, 500, 0);
            vm.stopPrank();

            vm.startPrank(borrower);
            usdc.approve(address(engine), 1333e6);
            engine.requestBorrow(1000e6, 600, 0, 1333e6);
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
