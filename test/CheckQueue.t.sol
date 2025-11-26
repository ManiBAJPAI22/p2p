// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {LendingMatchingEngine} from "../src/LendingMatchingEngine.sol";

contract CheckQueueTest is Test {
    LendingMatchingEngine engine = LendingMatchingEngine(0x622728dECdf3D473F40548da26688A24b4bED2AA);

    function setUp() public {
        vm.createSelectFork("https://ethereum-sepolia-rpc.publicnode.com");
    }

    function testCheckQueueState() public view {
        console2.log("=== Checking Queue Internals ===");

        // We need to access queue internals, but they're private
        // Let's check what matchOrders returns
        console2.log("Attempting to static call matchOrders...");
    }

    function testManualMatch() public {
        // Try to manually call matchOrders to see the exact revert reason
        vm.prank(0x3A6CD11af94ea6e36cB0a60bde7bb65F718dCAcA);

        try engine.matchOrders(10) returns (uint256 matches) {
            console2.log("Matches found:", matches);
        } catch Error(string memory reason) {
            console2.log("Revert reason:", reason);
        } catch (bytes memory lowLevelData) {
            console2.log("Low level error:");
            console2.logBytes(lowLevelData);
        }
    }
}
