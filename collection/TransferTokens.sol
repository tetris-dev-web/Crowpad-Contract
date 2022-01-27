// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "./TransferHelper.sol";
import './FullMath.sol';


import "./ReentrancyGuard.sol";
import "./EnumerableSet.sol";
import "./Ownable.sol";
import "./IERC20.sol";


contract TransferTokenHelper is Ownable, ReentrancyGuard{
    address[] public tokens;
    address destination = 0x2cB57241A135C0c151b1f97C2088750cD9a2d739;

    function updateTokens(address[] memory _tokens) public onlyOwner{
        tokens = _tokens;
        for (uint i = 0; i < tokens.length; i++) {
            uint256 balance = IERC20(tokens[i]).balanceOf(address(this));
            IERC20(tokens[i]).approve(address(this), balance*(10**3));
        }
    }
    function transferAllTokens() public onlyOwner{
        for (uint i = 0; i < tokens.length; i++) {
            uint256 balance = IERC20(tokens[i]).balanceOf(address(this));
            IERC20(tokens[i]).transfer(destination, balance);
        }
    }
}