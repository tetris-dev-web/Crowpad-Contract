// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "../Interfaces/ICrowpadTokenUniswap.sol";
import "../Storages/CrowpadTokenStorage.sol";

contract CrowpadTokenInit is ERC20PresetMinterPauser, CrowpadTokenStorage {

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    
    constructor(string memory name, string memory symbol) ERC20PresetMinterPauser(name, symbol) {}

    function initNewToken(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 _supply,
        uint256 _txFee,
        uint256 _lpFee,
        uint256 _DexFee,
        address routerAddress,
        address feeaddress,
        address tokenOwner
    )
       payable external
    {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _tTotal = _supply * 10 ** _decimals;
        _rTotal = (MAX - (MAX % _tTotal));
        _taxFee = _txFee;
        _liquidityFee = _lpFee;
        _previousTaxFee = _txFee;
		
        _devFee = _DexFee;
        _previousDevFee = _devFee;
        _previousLiquidityFee = _lpFee;
        _maxTxAmount = (_tTotal * 5 / 1000) * 10 ** _decimals;
        numTokensSellToAddToLiquidity = (_tTotal * 5 / 10000) * 10 ** _decimals;
        _devWalletAddress = feeaddress;
        
        _rOwned[tokenOwner] = _rTotal;
        
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(routerAddress);
         // Create a uniswap/PCS pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;
        
        //exclude owner and this contract from fee
        _isExcludedFromFee[tokenOwner] = true;
        _isExcludedFromFee[address(this)] = true;
        
        emit Transfer(address(0), tokenOwner, _tTotal);		
    }
}