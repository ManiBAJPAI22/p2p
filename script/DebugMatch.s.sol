// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {LendingMatchingEngine} from "../src/LendingMatchingEngine.sol";

contract DebugMatchScript is Script {
    LendingMatchingEngine constant engine = LendingMatchingEngine(0x622728dECdf3D473F40548da26688A24b4bED2AA);

    function run() external view {
        // Check order counters
        console2.log("=== Order Counters ===");
        console2.log("Next Lender Order ID:", engine.nextLenderOrderId());
        console2.log("Next Borrow Order ID:", engine.nextBorrowOrderId());
        console2.log("");

        // Check latest lender order
        console2.log("=== Lender Order #4 ===");
        (address lOwner, uint96 lAmount, uint96 lRemaining, uint16 lMinRate, uint8 lTerm, uint32 lCreated, uint8 lBucket) =
            engine.lenderOrders(4);
        console2.log("Owner:", lOwner);
        console2.log("Amount:", lAmount);
        console2.log("Remaining:", lRemaining);
        console2.log("MinRateBps:", lMinRate);
        console2.log("Term:", lTerm);
        console2.log("RateBucket:", lBucket);
        console2.log("");

        // Check latest borrow order
        console2.log("=== Borrow Order #3 ===");
        (address bOwner, uint96 bAmount, uint96 bRemaining, uint16 bMaxRate, uint8 bTerm, uint32 bCreated, uint8 bBucket, uint96 bCollateral) =
            engine.borrowOrders(3);
        console2.log("Owner:", bOwner);
        console2.log("Amount:", bAmount);
        console2.log("Remaining:", bRemaining);
        console2.log("MaxRateBps:", bMaxRate);
        console2.log("Term:", bTerm);
        console2.log("RateBucket:", bBucket);
        console2.log("Collateral:", bCollateral);
        console2.log("");

        // Check match condition
        console2.log("=== Match Analysis ===");
        console2.log("Both same term?", lTerm == bTerm);
        console2.log("Rates compatible?", lMinRate <= bMaxRate);
        console2.log("Both have remaining?", lRemaining > 0 && bRemaining > 0);
        console2.log("Should match:", lTerm == bTerm && lMinRate <= bMaxRate && lRemaining > 0 && bRemaining > 0);
    }
}
