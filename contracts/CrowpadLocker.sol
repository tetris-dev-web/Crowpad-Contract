// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CrowpadLocker is Ownable {

    using SafeERC20 for IERC20;

    event Deposit(address indexed hodler, address token, uint256 amount, uint256 lockTime, uint256 unlockTime, uint256 feePercentage);
    event EmergencyWithdraw(address indexed hodler, address token, uint256 amount, uint256 lockTime, uint256 unlockTime, uint256 feePercentage);
    event Withdraw(address indexed hodler, address token, uint256 amount, uint256 lockTime, uint256 unlockTime, uint256 feePercentage);
    event FeesClaimed();

    struct Hodler {
        address hodlerAddress;
        mapping(address => Token) tokens;
    }

    struct Token {
        address tokenAddress;
        uint256 balance;
        uint256 lockTime;
        uint256 unlockTime;
        uint256 feePercentage;
    }

    mapping(address => Hodler) public hodlers;

    /**
    * @notice Deposit token to Locker
    * @param _tokenAddress address of token to deposit
    * @param _amount amount of token to deposit
    * @param _unlockTime unlock time of token
    * @param _feePercentage fee percentage
    * @dev
    */
    function deposit(
        address _tokenAddress,
        uint256 _amount,
        uint256 _unlockTime,
        uint256 _feePercentage
    ) public {
        require(_feePercentage >= 10, "Minimal fee is 10%.");

        Hodler storage hodler = hodlers[msg.sender];
        hodler.hodlerAddress = msg.sender;
        Token storage lockedToken = hodlers[msg.sender].tokens[_tokenAddress];
        uint256 lockTime = block.timestamp;

        if (lockedToken.balance > 0) {
            lockedToken.balance += _amount;
            if (lockedToken.feePercentage < _feePercentage) {
                lockedToken.feePercentage = _feePercentage;
            }
            if (lockedToken.unlockTime < _unlockTime) {
                lockedToken.unlockTime = _unlockTime;
            }
            lockedToken.lockTime = lockTime;
        } else {
            hodlers[msg.sender].tokens[_tokenAddress] = Token(_tokenAddress, _amount, lockTime, _unlockTime, _feePercentage);
        }

        IERC20(_tokenAddress).safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(msg.sender, _tokenAddress, _amount, lockTime, _unlockTime, _feePercentage);
    }

    /**
    * @notice Withdraw token from Locker
    * @param _tokenAddress address of token to withdraw
    * @param _amount amount of token to withdraw
    * @dev
    */
    function withdraw(address _tokenAddress, uint256 _amount) public {
        Hodler storage hodler = hodlers[msg.sender];
        require(msg.sender == hodler.hodlerAddress, "Only available to the token owner.");
        require(block.timestamp > hodler.tokens[_tokenAddress].unlockTime, "Unlock time not reached yet.");

        uint256 totalBalance = IERC20(_tokenAddress).balanceOf(address(this));
        require(_amount <= totalBalance, "Amount to withdraw must be less than total supply.");

        uint256 withdrawableAmount = hodler.tokens[_tokenAddress].balance;
        require(withdrawableAmount > 0, "No balance");
        require(_amount <= withdrawableAmount, "Amount to withdraw must be less than balance.");

        hodler.tokens[_tokenAddress].balance = withdrawableAmount - _amount;
        IERC20(_tokenAddress).safeTransfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _tokenAddress, _amount, hodler.tokens[_tokenAddress].lockTime, hodler.tokens[_tokenAddress].unlockTime, hodler.tokens[_tokenAddress].feePercentage);
    }

    /**
    * @notice Emergency withdraw token from Locker
    * @param _tokenAddress address of token to withdraw
    * @param _amount amount of token to withdraw
    * @dev
    */
    function emergencyWithdraw(address _tokenAddress, uint256 _amount) public {
        Hodler storage hodler = hodlers[msg.sender];
        require(msg.sender == hodler.hodlerAddress, "Only available to the token owner.");

        uint256 totalBalance = IERC20(_tokenAddress).balanceOf(address(this));
        require(_amount <= totalBalance, "Amount to withdraw must be less than total supply.");

        uint256 withdrawableAmount = hodler.tokens[_tokenAddress].balance;
        require(withdrawableAmount > 0, "No balance");
        require(_amount <= withdrawableAmount, "Amount to withdraw must be less than balance.");

        uint256 feeAmount = _amount / 100 * hodler.tokens[_tokenAddress].feePercentage;
        uint256 withdrawalAmount = _amount - feeAmount;

        hodler.tokens[_tokenAddress].balance = withdrawableAmount - _amount;

        // Transfers fees to the contract administrator/owner
        hodlers[owner()].tokens[_tokenAddress].balance += feeAmount;

        IERC20(_tokenAddress).safeTransfer(msg.sender, withdrawalAmount);

        emit EmergencyWithdraw(msg.sender, _tokenAddress, withdrawalAmount, hodler.tokens[_tokenAddress].unlockTime, hodler.tokens[_tokenAddress].unlockTime, hodler.tokens[_tokenAddress].feePercentage);
    }

    /**
    * @notice Claim fees
    * @param _tokenAddressList array of token address to claim fee
    * @dev
    */
    function claimTokenListFees(address[] memory _tokenAddressList) public onlyOwner {
        for (uint256 i = 0; i < _tokenAddressList.length; i++) {
            uint256 amount = hodlers[owner()].tokens[_tokenAddressList[i]].balance;
            if (amount > 0) {
                hodlers[owner()].tokens[_tokenAddressList[i]].balance = 0;
                IERC20(_tokenAddressList[i]).safeTransfer(owner(), amount);
            }
        }
        emit FeesClaimed();
    }

    /**
    * @notice Claim fee
    * @param _tokenAddress token address to claim fee
    * @dev
    */
    function claimTokenFees(address _tokenAddress) public onlyOwner {
        uint256 amount = hodlers[owner()].tokens[_tokenAddress].balance;
        require(amount > 0, "No fees available for claiming.");

        hodlers[owner()].tokens[_tokenAddress].balance = 0;
        IERC20(_tokenAddress).safeTransfer(owner(), amount);
        emit FeesClaimed();
    }
}
