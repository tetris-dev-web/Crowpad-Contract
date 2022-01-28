// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "./crowpadsale/Crowdsale.sol";
import "./crowpadsale/validation/CappedCrowdsale.sol";
import "./crowpadsale/validation/TimedCrowdsale.sol";
import "./crowpadsale/distribution/RefundablePostDeliveryCrowdsale.sol";

contract CrowpadSale is Crowdsale, CappedCrowdsale, TimedCrowdsale, RefundablePostDeliveryCrowdsale, Ownable {
    using SafeMath for uint256;

    // Track investor contributions
    uint256 public investorMinCap = 2000000000000000; // 0.002 ether
    uint256 public investorHardCap = 50000000000000000000; // 50 ether
    mapping(address => uint256) public contributions;

    // Crowdsale Stages
    enum CrowdsaleStage { PreICO, ICO }
    // Default to presale stage
    CrowdsaleStage public stage = CrowdsaleStage.PreICO;

    // Token Distribution
    uint256 public tokenSalePercentage   = 70;

    // Token time lock
    uint256 public releaseTime;

    // Token Owner
    address payable private _tokenOwner;

    constructor(
        uint256 _rate,
        address payable _wallet,
        IERC20 _token,
        address payable tokenOwner,
        uint256 _cap,
        uint256 _openingTime,
        uint256 _closingTime,
        uint256 _goal,
        uint256 _releaseTime
    )
        Crowdsale(_rate, _wallet, _token)
        CappedCrowdsale(_cap)
        TimedCrowdsale(_openingTime, _closingTime)
        RefundablePostDeliveryCrowdsale(_goal)
    {
        require(_goal <= _cap, "Goal can not be greater than Cap.");
        releaseTime    = _releaseTime;
        _tokenOwner = tokenOwner;
    }

    /**
    * @dev Returns the amount contributed so far by a sepecific user.
    * @param _beneficiary Address of contributor
    * @return User contribution so far
    */
    function getUserContribution(address _beneficiary) public view returns (uint256) {
        return contributions[_beneficiary];
    }

    /**
    * @dev Allows admin to update the crowdsale stage
    * @param _stage Crowdsale stage
    */
    function setCrowdsaleStage(uint _stage) public onlyOwner {
        if (uint(CrowdsaleStage.PreICO) == _stage) {
            stage = CrowdsaleStage.PreICO;
        } else if (uint(CrowdsaleStage.ICO) == _stage) {
            stage = CrowdsaleStage.ICO;
        }

        if (stage == CrowdsaleStage.PreICO) {
            // rate = 500;
            // change crowsale's rate
        } else if (stage == CrowdsaleStage.ICO) {
            // rate = 250;
            // change crowsale's rate
        }
    }

    /**
    * @dev Initial Deposite from tokenOwner
    * @param amount Total amount of deposite
    */
    function Deposite(uint256 amount) public {
        require(msg.sender == _tokenOwner, "Only token owner can deposite");
        require(token().balanceOf(_tokenOwner) > amount, "Insufficent balance");

        token().transfer(address(this), amount);
    }

    /**
    * @dev forwards funds to the wallet during the PreICO stage, then the refund vault during ICO stage
    */
    function _forwardFunds() internal override(Crowdsale, RefundablePostDeliveryCrowdsale) {
        if (stage == CrowdsaleStage.PreICO) {
            wallet().transfer(msg.value);
        } else if (stage == CrowdsaleStage.ICO) {
            super._forwardFunds();
        }
    }

    /**
    * @dev Extend parent behavior requiring purchase to respect investor min/max funding cap.
    * @param _beneficiary Token purchaser
    * @param _weiAmount Amount of wei contributed
    */
    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal override(CappedCrowdsale, Crowdsale, TimedCrowdsale) {
        super._preValidatePurchase(_beneficiary, _weiAmount);
        uint256 _existingContribution = contributions[_beneficiary];
        uint256 _newContribution = _existingContribution.add(_weiAmount);
        require(_newContribution >= investorMinCap && _newContribution <= investorHardCap, "investorMinCap < contribution < investorHardCap");
        contributions[_beneficiary] = _newContribution;
    }

    function _processPurchase(address beneficiary, uint256 tokenAmount) internal override(Crowdsale, RefundablePostDeliveryCrowdsale) {
        RefundablePostDeliveryCrowdsale._processPurchase(beneficiary, tokenAmount);
    }

    /**
     * @dev Escrow finalization task, called when finalize() is called.
     */
    function _finalization() internal virtual override {
        // Refund remained token to owner
        if (goalReached() && !capReached()) {
            _deliverTokens(_tokenOwner, token().balanceOf(address(this)));
        }

        super._finalization();
    }
}