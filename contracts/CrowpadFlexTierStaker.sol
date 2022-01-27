// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CrowpadBaseTierStaker.sol";

contract CrowpadFlexTierStaker is CrowpadBaseTierStaker {

    uint8 public tierId = 0;
    uint8 public multiplier = 10; // in 1000
    uint8 public emergencyWithdrawlFee = 10;
    uint8 public enableEmergencyWithdrawl = 0;
    uint8 public enableRewards = 0; //disable rewards
    uint256 public unlockDuration = 7 * 24 * 60 * 60; // 7 days

    constructor(
        address _depositor,
        address _tokenAddress,
        address _feeAddress
    ) CrowpadBaseTierStaker(
        tierId,
        multiplier,
        emergencyWithdrawlFee,
        enableEmergencyWithdrawl,
        unlockDuration,
        enableRewards,
        _depositor,
        _tokenAddress,
        _feeAddress
    ) {
        //
    }
  
}