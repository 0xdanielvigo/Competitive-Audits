// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IMerge {
    enum LockedStatus {
        Locked,
        OneWay,
        TwoWay
    }

    error MergeEnded();
    error MergeLocked();
    error InvalidTokenReceived();
    error InvalidAmountReceived();
    error ZeroAmount();
    error TooEarlyToClaimRemainingTitn();
    error TooLateToClaimRemainingTitn();
}
