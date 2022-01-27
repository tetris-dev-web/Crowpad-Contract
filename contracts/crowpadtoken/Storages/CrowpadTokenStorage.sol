// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Interfaces/ICrowpadTokenUniswap.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract CrowpadTokenStorage is Ownable {

    address public implementation;

    mapping (address => uint256) internal _rOwned;
    mapping (address => uint256) internal _tOwned;
    mapping (address => bool) internal _isExcludedFromFee;
    mapping (address => bool) internal _isExcluded;

    address[] internal _excluded;
    address public _devWalletAddress;     // Wallet needs to be added by user after contract is deployed
    uint256 internal constant MAX = ~uint256(0);
    uint256 internal _tTotal;
    uint256 internal _rTotal;
    uint256 internal _tFeeTotal;
    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;
    uint256 public _taxFee;
    uint256 internal _previousTaxFee;
    uint256 public _devFee;
    uint256 internal _previousDevFee;
    uint256 public _liquidityFee;
    uint256 internal _previousLiquidityFee;
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    uint256 public _maxTxAmount;
    uint256 public numTokensSellToAddToLiquidity;
}