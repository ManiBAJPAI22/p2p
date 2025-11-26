// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DataTypes} from "./DataTypes.sol";

/**
 * @title OrderQueue
 * @notice Gas-efficient queue implementation using bucketed FIFO with bitset
 * @dev Uses 25 bps rate buckets and bitset to track non-empty buckets
 */
library OrderQueue {
    // Custom errors for gas efficiency
    error EmptyQueue();
    error InvalidBucket();
    error OrderNotFound();

    struct Queue {
        // Bitset to track non-empty buckets (2621 buckets / 256 = 11 uint256s)
        uint256[11] bucketBitset;
        // Mapping: rateBucket => term => array of order IDs
        mapping(uint8 => mapping(uint8 => uint256[])) bucketOrders;
        // Mapping: rateBucket => term => head index (for FIFO)
        mapping(uint8 => mapping(uint8 => uint256)) bucketHeads;
    }

    /**
     * @notice Add an order to the queue
     * @param queue The queue storage pointer
     * @param rateBucket The rate bucket
     * @param term The term bucket (0=7d, 1=30d, 2=90d)
     * @param orderId The order ID to add
     */
    function enqueue(Queue storage queue, uint8 rateBucket, uint8 term, uint256 orderId) internal {
        if (rateBucket >= DataTypes.MAX_RATE_BUCKETS) revert InvalidBucket();

        queue.bucketOrders[rateBucket][term].push(orderId);

        // Set bit in bitset
        uint256 wordIndex = rateBucket / 256;
        uint256 bitIndex = rateBucket % 256;
        queue.bucketBitset[wordIndex] |= (1 << bitIndex);
    }

    /**
     * @notice Remove an order from the front of the queue
     * @param queue The queue storage pointer
     * @param rateBucket The rate bucket
     * @param term The term bucket
     */
    function dequeue(Queue storage queue, uint8 rateBucket, uint8 term) internal {
        if (rateBucket >= DataTypes.MAX_RATE_BUCKETS) revert InvalidBucket();

        uint256 head = queue.bucketHeads[rateBucket][term];
        uint256[] storage orders = queue.bucketOrders[rateBucket][term];

        if (head >= orders.length) revert EmptyQueue();

        // Move head forward instead of shifting array (gas efficient)
        queue.bucketHeads[rateBucket][term]++;

        // If bucket is now empty, clear the bit
        if (queue.bucketHeads[rateBucket][term] >= orders.length) {
            // Check if all terms are empty for this bucket
            bool allTermsEmpty = true;
            for (uint8 t = 0; t < 3; t++) {
                if (queue.bucketHeads[rateBucket][t] < queue.bucketOrders[rateBucket][t].length) {
                    allTermsEmpty = false;
                    break;
                }
            }

            if (allTermsEmpty) {
                uint256 wordIndex = rateBucket / 256;
                uint256 bitIndex = rateBucket % 256;
                queue.bucketBitset[wordIndex] &= ~(1 << bitIndex);
            }
        }
    }

    /**
     * @notice Get the first order from the queue without removing it
     * @param queue The queue storage pointer
     * @param rateBucket The rate bucket
     * @param term The term bucket
     * @return The order ID at the front
     */
    function peek(Queue storage queue, uint8 rateBucket, uint8 term) internal view returns (uint256) {
        if (rateBucket >= DataTypes.MAX_RATE_BUCKETS) revert InvalidBucket();

        uint256 head = queue.bucketHeads[rateBucket][term];
        uint256[] storage orders = queue.bucketOrders[rateBucket][term];

        if (head >= orders.length) revert EmptyQueue();

        return orders[head];
    }

    /**
     * @notice Check if a bucket is empty
     * @param queue The queue storage pointer
     * @param rateBucket The rate bucket
     * @param term The term bucket
     * @return True if the bucket is empty
     */
    function isEmpty(Queue storage queue, uint8 rateBucket, uint8 term) internal view returns (bool) {
        uint256 head = queue.bucketHeads[rateBucket][term];
        uint256[] storage orders = queue.bucketOrders[rateBucket][term];
        return head >= orders.length;
    }

    /**
     * @notice Get the lowest non-empty lender bucket (best rate for borrowers)
     * @param queue The queue storage pointer
     * @param term The term bucket
     * @return rateBucket The lowest rate bucket, or type(uint8).max if queue is empty
     */
    function getLowestNonEmptyBucket(Queue storage queue, uint8 term) internal view returns (uint8) {
        // Scan bitset from lowest to highest
        for (uint256 wordIndex = 0; wordIndex < 11; wordIndex++) {
            uint256 word = queue.bucketBitset[wordIndex];
            if (word == 0) continue;

            // Find first set bit in this word
            for (uint256 bitIndex = 0; bitIndex < 256; bitIndex++) {
                if ((word & (1 << bitIndex)) != 0) {
                    uint8 bucket = uint8(wordIndex * 256 + bitIndex);
                    if (!isEmpty(queue, bucket, term)) {
                        return bucket;
                    }
                }
            }
        }

        return type(uint8).max; // Empty queue
    }

    /**
     * @notice Get the highest non-empty borrow bucket (best rate for lenders)
     * @param queue The queue storage pointer
     * @param term The term bucket
     * @return rateBucket The highest rate bucket, or type(uint8).max if queue is empty
     */
    function getHighestNonEmptyBucket(Queue storage queue, uint8 term) internal view returns (uint8) {
        // Scan bitset from highest to lowest
        for (uint256 wordIndex = 10; ; ) {
            uint256 word = queue.bucketBitset[wordIndex];
            if (word != 0) {
                // Find last set bit in this word - scan from high to low
                for (uint256 bitIndex = 255; ; ) {
                    if ((word & (1 << bitIndex)) != 0) {
                        uint8 bucket = uint8(wordIndex * 256 + bitIndex);
                        if (!isEmpty(queue, bucket, term)) {
                            return bucket;
                        }
                    }
                    if (bitIndex == 0) break;
                    bitIndex--;
                }
            }
            if (wordIndex == 0) break;
            wordIndex--;
        }

        return type(uint8).max; // Empty queue
    }
}
