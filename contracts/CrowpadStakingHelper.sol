// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import './FullMath.sol';
import "./Pausable.sol";

// interface ITokenLocker {
//     function convertSharesToTokens(address _token, uint256 _shares) external view returns (uint256);
//     function LOCKS(uint256 lockId) external view returns (address, uint256, uint256, uint256, uint256, uint256, address, string memory);
// }

contract CrowpadStakingHelper is Ownable, ReentrancyGuard, Pausable {

    using SafeERC20 for IERC20;
    
    struct Settings {
        uint256 startTimeForDeposit;
        uint256 endTimeForDeposit;
        uint256 ppMultiplier;
        uint256 privateSaleMultiplier;
        uint256 privateSaleTotalPP;
        uint256 withdrawalSuspensionStartTime;
        uint256 withdrawalSuspensionEndTime;
    }

    // mapping(address => uint256[]) public privateSaleUserLockerIds;
    uint256[] public privateSaleLockerIds;
    address public privateSaleLockerAddress;
    // ITokenLocker private tokenLocker;
    Settings public SETTINGS;

    constructor(
        uint256 _startTimeForDeposit,
        uint256 _endTimeForDeposit,
        uint256 _ppMultiplier,
        uint256 _privateSaleMultiplier,
        address _privateSaleLockerAddress
    ) {
        SETTINGS.startTimeForDeposit = _startTimeForDeposit;
        SETTINGS.endTimeForDeposit = _endTimeForDeposit;
        SETTINGS.ppMultiplier = _ppMultiplier;
        SETTINGS.privateSaleMultiplier = _privateSaleMultiplier;
        SETTINGS.withdrawalSuspensionEndTime = 0;
        SETTINGS.withdrawalSuspensionStartTime = 0;
        privateSaleLockerAddress = _privateSaleLockerAddress;
    }

    receive() external payable {
       revert('No Direct Transfer');
    }

    // function getUserSPP(address _user) external view returns (uint256) {
    //     uint256 userTotalPP = 0;
    //     uint256 tierTotalPP = 0;

    //     for (uint256 i = 0; i < stakingTierAddresses.length; i++) {
    //         (uint256 _userTierPP, uint256 _tierPP) = IStakingTierContract(stakingTierAddresses[i]).getPoolPercentagesWithUser(_user);
    //         userTotalPP += _userTierPP;
    //         tierTotalPP += _tierPP;
    //     }

    //     for (uint256 i = 0; i < privateSaleUserLockerIds[_user].length; i++) {
    //         userTotalPP += _getLockedPrivateSaleTokens(privateSaleUserLockerIds[_user][i]) * SETTINGS.privateSaleMultiplier;
    //     }

    //     tierTotalPP += SETTINGS.privateSaleTotalPP;
    //     return FullMath.mulDiv(userTotalPP, SETTINGS.ppMultiplier, tierTotalPP);
    // }

    function depositEnabled() external view returns (bool) {
        return _depositEnabled();
    }

    function _depositEnabled() internal view returns (bool) {
        return block.timestamp > SETTINGS.startTimeForDeposit && block.timestamp < SETTINGS.endTimeForDeposit;
    }

    function updateTime(uint256 _startTimeForDeposit, uint256 _endTimeForDeposit) external onlyOwner {
        SETTINGS.startTimeForDeposit = _startTimeForDeposit;
        SETTINGS.endTimeForDeposit = _endTimeForDeposit;
    }

    function transferExtraTokens(address _token, address _to, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(_to, _amount);
    }

    // function setPrivateSaleLockerIds(uint256[] memory _privateSaleLockerIds, address[] memory _privateSaleLockerOwners) external onlyOwner {
    //     require(_privateSaleLockerIds.length == _privateSaleLockerOwners.length, "Length Not Matched");

    //     for (uint256 i = 0; i < _privateSaleLockerOwners.length; i++) {
    //         address owner = _privateSaleLockerOwners[i];
    //         delete privateSaleUserLockerIds[owner];
    //     }

    //     for (uint256 i = 0; i < _privateSaleLockerIds.length; i++) {
    //         address owner = _privateSaleLockerOwners[i];
    //         uint256 lockId = _privateSaleLockerIds[i];

    //         privateSaleUserLockerIds[owner].push(lockId);
    //     }

    //     privateSaleLockerIds = _privateSaleLockerIds;
    // }

    function updatePrivateSaleTotalPP(uint256 _privateSaleTotalPP) external onlyOwner {
        SETTINGS.privateSaleTotalPP = _privateSaleTotalPP;
    }

    // function getLockedPrivateSaleTokens(uint256 lockerId) external view returns (uint256) {
    //     return _getLockedPrivateSaleTokens(lockerId);
    // }

    // function _getLockedPrivateSaleTokens(uint256 lockerId) internal view returns (uint256) {
    //     ( , uint256 sharesDeposited, uint256 sharesWithdrawn ,,,,,) = tokenLocker.LOCKS(lockerId);
    //    return tokenLocker.convertSharesToTokens(SETTINGS.tokenAddress,sharesDeposited - sharesWithdrawn); 
    // }

    // function updatePrivateSaleTotalPPFromContract() external onlyOwner {
    //     uint256 privateSaleTotalPP = 0;
    //     for (uint256 i = 0; i < privateSaleLockerIds.length; i++) {
    //         privateSaleTotalPP += (_getLockedPrivateSaleTokens(privateSaleLockerIds[i]) * SETTINGS.privateSaleMultiplier);
    //     }
    //     SETTINGS.privateSaleTotalPP = privateSaleTotalPP;
    // }

    function isWithdrawlAllowed() internal view returns (bool) {
        return block.timestamp < SETTINGS.withdrawalSuspensionStartTime || block.timestamp > SETTINGS.withdrawalSuspensionEndTime;
    }

    function setWithdrawalSuspension(uint256 _withdrawalSuspensionStartTime, uint256 _withdrawalSuspensionEndTime) external onlyOwner {
        SETTINGS.withdrawalSuspensionStartTime = _withdrawalSuspensionStartTime;
        SETTINGS.withdrawalSuspensionEndTime = _withdrawalSuspensionEndTime;
    }
}

