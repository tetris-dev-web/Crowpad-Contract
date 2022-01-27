// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CrowpadTokenValues.sol";

contract CrowpadTokenTransfer is CrowpadTokenValues {
    using SafeMath for uint256;
    using Address for address;

	event SwapAndLiquify(
		uint256 tokensSwapped,
		uint256 ethReceived,
		uint256 tokensIntoLiqudity
	);

	modifier lockTheSwap {
		inSwapAndLiquify = true;
		_;
		inSwapAndLiquify = false;
	}

	constructor(string memory name, string memory symbol) CrowpadTokenValues(name, symbol) {}

	function removeAllFee() private { 
		_previousTaxFee = _taxFee;
		_previousDevFee = _devFee;
		_previousLiquidityFee = _liquidityFee;
		
		_taxFee = 0;
		_devFee = 0;
		_liquidityFee = 0;
	}
	
	function restoreAllFee() private {
		_taxFee = _previousTaxFee;
		_devFee = _previousDevFee;
		_liquidityFee = _previousLiquidityFee;
	}

	function _transfer(
		address from,
		address to,
		uint256 amount
	) internal override {
		require(from != address(0), "ERC20: transfer from the zero address");
		require(to != address(0), "ERC20: transfer to the zero address");
		require(amount > 0, "Transfer amount must be greater than zero");
		if(from != owner() && to != owner())
			require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");

		uint256 contractTokenBalance = balanceOf(address(this));
		
		if(contractTokenBalance >= _maxTxAmount)
		{
			contractTokenBalance = _maxTxAmount;
		}
		
		bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
		if (
			overMinTokenBalance &&
			!inSwapAndLiquify &&
			from != uniswapV2Pair &&
			swapAndLiquifyEnabled
		) {
			contractTokenBalance = numTokensSellToAddToLiquidity;
			swapAndLiquify(contractTokenBalance);
		}
		
		bool takeFee = true;
		if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
			takeFee = false;
		}
		
		_tokenTransfer(from,to,amount,takeFee);
	}

	function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
		uint256 half = contractTokenBalance.div(2);
		uint256 otherHalf = contractTokenBalance.sub(half);
		uint256 initialBalance = address(this).balance;
		swapTokensForEth(half); 
		uint256 newBalance = address(this).balance.sub(initialBalance);
		addLiquidity(otherHalf, newBalance);
		emit SwapAndLiquify(half, newBalance, otherHalf);
	}

	function swapTokensForEth(uint256 tokenAmount) private {
		address[] memory path = new address[](2);
		path[0] = address(this);
		path[1] = uniswapV2Router.WETH();
		_approve(address(this), address(uniswapV2Router), tokenAmount);
		uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
			tokenAmount,
			0, // accept any amount of ETH
			path,
			address(this),
			block.timestamp
		);
	}

	function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
		_approve(address(this), address(uniswapV2Router), tokenAmount);
		uniswapV2Router.addLiquidityETH{value: ethAmount}(
			address(this),
			tokenAmount,
			0, // slippage is unavoidable
			0, // slippage is unavoidable
			owner(),
			block.timestamp
		);
	}

	function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
		if(!takeFee)
			removeAllFee();
		
		if (_isExcluded[sender] && !_isExcluded[recipient]) {
			_transferFromExcluded(sender, recipient, amount);
		} else if (!_isExcluded[sender] && _isExcluded[recipient]) {
			_transferToExcluded(sender, recipient, amount);
		} else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
			_transferStandard(sender, recipient, amount);
		} else if (_isExcluded[sender] && _isExcluded[recipient]) {
			_transferBothExcluded(sender, recipient, amount);
		} else {
			_transferStandard(sender, recipient, amount);
		}
		
		if(!takeFee)
			restoreAllFee();
	}

	function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
		(uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tDev) = _getValues(tAmount);
		_tOwned[sender] = _tOwned[sender].sub(tAmount);
		_rOwned[sender] = _rOwned[sender].sub(rAmount);
		_tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
		_rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);        
		_takeLiquidity(tLiquidity);
		_takeDev(tDev);
		_reflectFee(rFee, tFee);
		emit Transfer(sender, recipient, tTransferAmount);
	}

	function _takeLiquidity(uint256 tLiquidity) private {
		uint256 currentRate =  _getRate();
		uint256 rLiquidity = tLiquidity.mul(currentRate);
		_rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
		if (_isExcluded[address(this)])
			_tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
	}
	
	function _takeDev(uint256 tDev) private {
		uint256 currentRate =  _getRate();
		uint256 rDev = tDev.mul(currentRate);
		_rOwned[_devWalletAddress] = _rOwned[_devWalletAddress].add(rDev);
		if (_isExcluded[_devWalletAddress])
			_tOwned[_devWalletAddress] = _tOwned[_devWalletAddress].add(tDev);
	}  

	function _reflectFee(uint256 _rFee, uint256 _tFee) private {
		_rTotal = _rTotal.sub(_rFee);
		_tFeeTotal = _tFeeTotal.add(_tFee);
	}
	
	function _transferStandard(address sender, address recipient, uint256 tAmount) private {
		(uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tDev) = _getValues(tAmount);
		_rOwned[sender] = _rOwned[sender].sub(rAmount);
		_rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
		_takeLiquidity(tLiquidity);
		_takeDev(tDev);
		_reflectFee(rFee, tFee);
		emit Transfer(sender, recipient, tTransferAmount);
	}

	function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
		(uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tDev) = _getValues(tAmount);
		_rOwned[sender] = _rOwned[sender].sub(rAmount);
		_tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
		_rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);           
		_takeLiquidity(tLiquidity);
		_takeDev(tDev);
		_reflectFee(rFee, tFee);
		emit Transfer(sender, recipient, tTransferAmount);
	}

	function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
		(uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tDev) = _getValues(tAmount);
		_tOwned[sender] = _tOwned[sender].sub(tAmount);
		_rOwned[sender] = _rOwned[sender].sub(rAmount);
		_rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);   
		_takeLiquidity(tLiquidity);
		_takeDev(tDev);
		_reflectFee(rFee, tFee);
		emit Transfer(sender, recipient, tTransferAmount);
	}  
}