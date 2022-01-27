// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CrowpadTokenValues.sol";

contract CrowpadTokenPure is CrowpadTokenValues {
    using SafeMath for uint256;
    using Address for address;

	constructor(string memory name, string memory symbol) CrowpadTokenValues(name, symbol) {}

	function decimals() public view override returns (uint8) {
		return _decimals;
	}

	function totalSupply() public view override returns (uint256) {
		return _tTotal;
	}

	function totalFees() public view returns (uint256) {
		return _tFeeTotal;
	}

	function isExcludedFromReward(address account) public view returns (bool) {
		return _isExcluded[account];
	}

	function excludeFromFee(address account) public onlyOwner {
		_isExcludedFromFee[account] = true;
	}
	
	function includeInFee(address account) public onlyOwner {
		_isExcludedFromFee[account] = false;
	}
	
	function setTaxFeePercent(uint256 taxFee) external onlyOwner {
		_taxFee = taxFee;
	}

	function setDevFeePercent(uint256 devFee) external onlyOwner {
		_devFee = devFee;
	}
	
	function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner {
		_liquidityFee = liquidityFee;
	}
	
	function setMaxTxPercent(uint256 maxTxPercent) public onlyOwner {
		_maxTxAmount = maxTxPercent  * 10 ** _decimals;
	}
	
	function setDevWalletAddress(address _addr) public onlyOwner {
		_devWalletAddress = _addr;
	}

	function balanceOf(address account) public view override returns (uint256) {
		if (_isExcluded[account]) return _tOwned[account];
		return tokenFromReflection(_rOwned[account]);
	}

	function deliver(uint256 tAmount) public {
		address sender = _msgSender();
		require(!_isExcluded[sender], "Excluded addresses cannot call this function");
		(uint256 rAmount,,,,,,) = _getValues(tAmount);
		_rOwned[sender] = _rOwned[sender].sub(rAmount);
		_rTotal = _rTotal.sub(rAmount);
		_tFeeTotal = _tFeeTotal.add(tAmount);
	}

	function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
		require(tAmount <= _tTotal, "Amount must be less than supply");
		if (!deductTransferFee) {
			(uint256 rAmount,,,,,,) = _getValues(tAmount);
			return rAmount;
		} else {
			(,uint256 rTransferAmount,,,,,) = _getValues(tAmount);
			return rTransferAmount;
		}
	}

	function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
		require(rAmount <= _rTotal, "Amount must be less than total reflections");
		uint256 currentRate =  _getRate();
		return rAmount.div(currentRate);
	}

	function excludeFromReward(address account) public onlyOwner {
		require(!_isExcluded[account], "Account is already excluded");
		if(_rOwned[account] > 0) {
			_tOwned[account] = tokenFromReflection(_rOwned[account]);
		}
		_isExcluded[account] = true;
		_excluded.push(account);
	}

	function includeInReward(address account) external onlyOwner {
		require(_isExcluded[account], "Account is already included");
		for (uint256 i = 0; i < _excluded.length; i++) {
			if (_excluded[i] == account) {
				_excluded[i] = _excluded[_excluded.length - 1];
				_tOwned[account] = 0;
				_isExcluded[account] = false;
				_excluded.pop();
				break;
			}
		}
	}

	function isExcludedFromFee(address account) public view returns(bool) {
		return _isExcludedFromFee[account];
	}
}