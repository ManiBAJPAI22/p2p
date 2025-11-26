// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library DataTypes {
    // Packed storage: 256 bits = 32 bytes
    // owner: 20 bytes (160 bits)
    // amount: 12 bytes (96 bits) - max ~79 billion tokens with 18 decimals
    // rateBps: 2 bytes (16 bits) - max 65535 bps (655.35%)
    // term: 1 byte (8 bits) - 0=7d, 1=30d, 2=90d
    // createdAt: 4 bytes (32 bits) - timestamp (good until year 2106)
    // remaining: 12 bytes (96 bits)
    struct LenderOrder {
        address owner;           // 160 bits
        uint96 amount;          // 96 bits (slot 0: 160+96=256)
        uint96 remaining;       // 96 bits
        uint16 minRateBps;      // 16 bits
        uint8 term;             // 8 bits
        uint32 createdAt;       // 32 bits (slot 1: 96+16+8+32=152, leaves 104 bits unused)
        uint8 rateBucket;       // 8 bits - for efficient queue lookup
    }

    struct BorrowOrder {
        address owner;           // 160 bits
        uint96 amount;          // 96 bits (slot 0: 160+96=256)
        uint96 remaining;       // 96 bits
        uint16 maxRateBps;      // 16 bits
        uint8 term;             // 8 bits
        uint32 createdAt;       // 32 bits (slot 1: 96+16+8+32=152)
        uint8 rateBucket;       // 8 bits
        uint96 collateralAmount; // 96 bits (slot 2)
    }

    struct LoanPosition {
        address lender;          // 160 bits
        address borrower;        // 160 bits (slot 0: 160, slot 1: 160)
        uint96 principal;        // 96 bits
        uint16 rateBps;         // 16 bits
        uint8 term;             // 8 bits
        uint32 startTime;       // 32 bits (slot 2: 96+16+8+32=152)
        uint96 collateralAmount; // 96 bits (slot 3)
        bool repaid;            // 8 bits
    }

    // Terms in seconds
    uint32 constant TERM_7D = 7 days;
    uint32 constant TERM_30D = 30 days;
    uint32 constant TERM_90D = 90 days;

    // Rate bucket size (25 bps = 0.25%)
    uint16 constant RATE_BUCKET_SIZE = 25;

    // Max rate buckets (0-65535 bps / 25 = 2621 buckets)
    uint16 constant MAX_RATE_BUCKETS = 2621;

    // Collateral LTV basis points (e.g., 7500 = 75% LTV)
    uint16 constant LTV_BPS = 7500;
    uint16 constant LIQUIDATION_LTV_BPS = 8000; // 80%

    function getTermDuration(uint8 term) internal pure returns (uint32) {
        if (term == 0) return TERM_7D;
        if (term == 1) return TERM_30D;
        if (term == 2) return TERM_90D;
        revert("Invalid term");
    }

    function getRateBucket(uint16 rateBps) internal pure returns (uint8) {
        return uint8(rateBps / RATE_BUCKET_SIZE);
    }
}
