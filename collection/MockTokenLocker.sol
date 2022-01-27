
pragma solidity ^0.8.0;
//SPDX-License-Identifier: UNLICENSED
contract MockTokenLocker{
     function getWithdrawableTokens (uint256 _lockID) external view returns (uint256){
         return (_lockID+1)* (10**18);
     }
}