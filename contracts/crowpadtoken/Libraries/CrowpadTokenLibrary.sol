// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @dev Wrappers over reusable operations of CrowpadToken.
 */
library CrowpadTokenLibrary {

    using SafeMath for uint256;

    /**
     * @dev Returns TValues
     */
    function getTValues(uint256 tAmount, uint256 taxFee, uint256 liquidityFee, uint256 devFee) public pure returns (uint256, uint256, uint256, uint256) {
        uint256 tFee = tAmount.mul(taxFee).div(100);
        uint256 tLiquidity = tAmount.mul(liquidityFee).div(100);
        uint256 tDev = tAmount.mul(devFee).div(100);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity);
        return (tTransferAmount.sub(tDev), tFee, tLiquidity, tDev);
    }

    /**
     * @dev Returns RValues
     */
    function getRValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 tDev, uint256 currentRate) public pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rDev = tDev.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity);
        return (rAmount, rTransferAmount.sub(rDev), rFee);
    }
}
