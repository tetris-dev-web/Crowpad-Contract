// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "./RefundableCrowdsale.sol";
import "./PostDeliveryCrowdsale.sol";

/**
 * @title RefundablePostDeliveryCrowdsale
 * @dev Extension of RefundableCrowdsale contract that only delivers the tokens
 * once the crowdsale has closed and the goal met, preventing refunds to be issued
 * to token holders.
 */
abstract contract RefundablePostDeliveryCrowdsale is RefundableCrowdsale, PostDeliveryCrowdsale {

    constructor (uint256 goal_) RefundableCrowdsale(goal_) {
        //
    }

    function withdrawTokens(address beneficiary) public override {
        require(finalized(), "RefundablePostDeliveryCrowdsale: not finalized");
        require(goalReached(), "RefundablePostDeliveryCrowdsale: goal not reached");

        super.withdrawTokens(beneficiary);
    }

    function _forwardFunds() internal virtual override(Crowdsale, RefundableCrowdsale) {
        RefundableCrowdsale._forwardFunds();
    }

    function _processPurchase(address beneficiary, uint256 tokenAmount) internal virtual override(Crowdsale, PostDeliveryCrowdsale) {
        PostDeliveryCrowdsale._processPurchase(beneficiary, tokenAmount);
    }
}
