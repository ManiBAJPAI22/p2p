// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ReentrancyGuard
 * @notice Gas-efficient reentrancy protection
 */
abstract contract ReentrancyGuard {
    error ReentrancyGuardReentrantCall();

    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert ReentrancyGuardReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}
