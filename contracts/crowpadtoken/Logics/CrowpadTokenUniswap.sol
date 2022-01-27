// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Interfaces/ICrowpadTokenUniswap.sol";
import "../Storages/CrowpadTokenStorage.sol";

contract CrowpadTokenUniswap is CrowpadTokenStorage {

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function setRouterAddress(address newRouter) external onlyOwner {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(newRouter);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
    }

    function setNumTokensSellToAddToLiquidity(uint256 amountToUpdate) external onlyOwner {
        numTokensSellToAddToLiquidity = amountToUpdate;
    }  
}