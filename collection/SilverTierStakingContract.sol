// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./TransferHelper.sol";
import './FullMath.sol';

import "./EnumerableSet.sol";
import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./IERC20.sol";
import "./BaseTierStakingContract.sol";

contract SilverTierStakingContract is BaseTierStakingContract {
  uint8 public tierId = 2;
  uint8 public multiplier = 20; // in 1000
  uint8 public emergencyWithdrawlFee = 20;
  uint8 public enableEmergencyWithdrawl = 0;
  uint8 public enableRewards = 1; // allow rewards of DexPad Fees
  
  uint256 public unlockDuration = 6*30*24*60*60; // 6 months
  constructor( address _depositor, address _tokenAddress, address _feeAddress, address _stakingHelper)
    BaseTierStakingContract(tierId,multiplier,emergencyWithdrawlFee,enableEmergencyWithdrawl, unlockDuration,  enableRewards, _depositor, _tokenAddress, _feeAddress, _stakingHelper) {
  }
  
}