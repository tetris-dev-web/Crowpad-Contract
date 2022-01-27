// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './CrowpadStakingHelper.sol';

interface IMigrator {
    function migrate(uint256 lockId, address owner, uint256 amount, uint256 ipp, uint256 unlockTime, uint256 lockTime) external returns (bool);
}

contract CrowpadBaseTierStaker is CrowpadStakingHelper {

    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    uint256 public CONTRACT_VERSION = 1;
  
    struct TokenLock {
        uint256 lockId;
        address owner;
        uint256 amount;
        uint256 iPP; // individual pool percentage
        uint256 unlockTime;
        uint256 lockTime;
    }

    struct Config {
        uint8 tierId; // 0 based index
        uint8 multiplier; // in 10 to support single decimal such as 0.1 and 1.2
        uint8 emergencyWithdrawlFee; // in 1000 so for 2% fee it will be 20
        uint8 enableEarlyWithdrawal;
        uint8 enableRewards;
        uint256 unlockDuration; // epoch timestamp
        address depositor;  // Depositor contract who is allowed to stake
        address feeAddress; // Address to receive the fee
    }

    struct LockParams {
        address payable owner; // the user who can withdraw tokens once the lock expires.
        uint256 amount; // amount of tokens to lock
    }

    EnumerableSet.AddressSet private users; 
    EnumerableSet.AddressSet private allowedMigrators; // Address of the contract that can migrate the tokens
    uint256 public tierTotalParticipationPoints;
    uint256 public nonce = 1; // incremental lock nonce counter, this is the unique ID for the next lock
    uint256 public minimumDeposit = 1000 * (10 ** 18); // minimum divisibility per lock at time of locking
    IERC20 public token; // token

    Config public config;
    mapping(uint256 => TokenLock) public locks; // map lockId nonce to the lock
    mapping(address => uint256[]) public userLocks; // UserAddress => LockId
    
    IMigrator public migrator;

    event OnLock(uint256 lockId, address owner, uint256 amountInTokens, uint256 iPP);
    event OnLockUpdated(uint256 lockId, address owner, uint256 amountInTokens, uint256 tierId);
    event OnWithdraw(uint256 lockId, address owner, uint256 amountInTokens);
    event OnFeeCharged(uint256 lockId, address owner, uint256 amountInTokens);
    event OnMigrate(uint256 lockId, address owner, uint256 amount, uint256 ipp, uint256 unlockTime, uint256 lockTime);
  
    constructor(
        uint8 _tierId,
        uint8 _multiplier,
        uint8 _emergencyWithdrawlFee,
        uint8 _enableEarlyWithdrawal,
        uint256 _unlockDuration,
        uint8 _enableRewards,
        address _depositor,
        address _tokenAddress,
        address _feeAddress
    ) CrowpadStakingHelper(
        0,
        0,
        0,
        0,
        0x0f2257997A3aF27C027377e4bdeed583F804cc83
    ) {
        token = IERC20(_tokenAddress);
        config.tierId = _tierId;
        config.multiplier = _multiplier;
        config.emergencyWithdrawlFee = _emergencyWithdrawlFee;
        config.unlockDuration = _unlockDuration;
        config.enableEarlyWithdrawal = _enableEarlyWithdrawal;
        config.depositor = _depositor;
        config.feeAddress = _feeAddress;
        config.enableRewards = _enableRewards;
    }  

    // /**
    // * @notice set the migrator contract which allows the lock to be migrated
    // */
    // function setMigrator(IMigrator _migrator) external onlyOwner {
    //     migrator = _migrator;
    // }  

    /**
    * @notice Creates one lock for the specified token
    * @param _owner the owner of the lock
    * @param _amount amount of the lock
    * owner: user or contract who can withdraw the tokens
    * amount: must be >= 100 units
    * Fails is amount < 100
    */
    function singleLock(address payable _owner, uint256 _amount) public {
        LockParams memory param = LockParams(_owner, _amount);
        LockParams[] memory params = new LockParams[](1);
        params[0] = param;
        _lock(params);
    }
  
    function _lock(LockParams[] memory _lockParams) internal nonReentrant {
        require(msg.sender == config.depositor, 'Only depositor can call this function');
        require(_lockParams.length > 0, 'NO PARAMS');

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _lockParams.length; i++) {
            require(_lockParams[i].owner != address(0), 'No ADDR');
            require(_lockParams[i].amount > 0, 'No AMT');
            totalAmount += _lockParams[i].amount;
        }

        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransferFrom(address(msg.sender), address(this), totalAmount);
        uint256 amountIn = token.balanceOf(address(this)) - balanceBefore;
        require(amountIn == totalAmount, 'NOT ENOUGH TOKEN');
        for (uint256 i = 0; i < _lockParams.length; i++) {
            LockParams memory lockParam = _lockParams[i];
            require(lockParam.amount >= minimumDeposit, 'MIN DEPOSIT');
            TokenLock memory tokenLock;
            tokenLock.lockId = nonce;
            tokenLock.owner = lockParam.owner;
            users.add(lockParam.owner);
            tokenLock.amount = lockParam.amount;
            tokenLock.lockTime = block.timestamp;
            tokenLock.unlockTime = block.timestamp + config.unlockDuration;
            tokenLock.iPP = lockParam.amount * config.multiplier;
            // record the lock globally
            locks[nonce] = tokenLock;
            tierTotalParticipationPoints += tokenLock.iPP;
            userLocks[tokenLock.owner].push(tokenLock.lockId);
            nonce++;
            emit OnLock(tokenLock.lockId, tokenLock.owner, tokenLock.amount, tokenLock.iPP);
        }
    }

    /**
    * @notice Creates multiple locks
    * @param _lockParams an array of locks with format: [LockParams[owner, amount]]
    * owner: user or contract who can withdraw the tokens
    * amount: must be >= 1000 units
    * Fails is amount < 1000
    */    
    function lock(LockParams[] memory _lockParams) external {
        _lock(_lockParams);
    }

    /**
    * @notice stake a specified amount to owner
    * @param _owner staking owner
    * @param _amount amount of token to stake
    */
    function stake(address payable _owner, uint256 _amount) external nonReentrant notPaused {
        require(_depositEnabled(), "Deposit is not enabled");
        require(_owner != address(0), 'No ADDRESS');
        require(_amount > 0, 'Amount of token to stake must be greater than 0');

        singleLock(_owner, _amount);
    }
  
    /**
    * @notice withdraw a specified amount from a lock. _amount is the ideal amount to be withdrawn.
    * however, this amount might be slightly different in rebasing tokens due to the conversion to shares,
    * then back into an amount
    * @param _lockId the lockId of the lock to be withdrawn
    */
    function withdraw(uint256 _lockId, uint256 _index, uint256 _amount) external nonReentrant {
        require(isWithdrawlAllowed(), 'NOT ALLOWED');

        TokenLock storage userLock = locks[_lockId];
        require(userLock.unlockTime <= block.timestamp || config.enableEarlyWithdrawal == 1, 'Early withdrawal is disabled');
        require(userLocks[msg.sender].length > _index, 'Index OOB');
        require(userLocks[msg.sender][_index] == _lockId, 'lockId NOT MATCHED');
        require(userLock.owner == msg.sender, 'OWNER');

        uint256 balance = token.balanceOf(address(this));
        uint256 withdrawableAmount = locks[_lockId].amount;
        require(withdrawableAmount > 0, 'NO TOKENS');
        require(_amount <= withdrawableAmount, 'AMOUNT < WAMNT');
        require(_amount <= balance, 'NOT ENOUGH TOKENS');

        locks[_lockId].amount = withdrawableAmount - _amount;
        uint256 decreaseIPP = _amount * config.multiplier;
        tierTotalParticipationPoints -= decreaseIPP;
        locks[_lockId].iPP -= decreaseIPP;

        if (userLock.unlockTime > block.timestamp && config.emergencyWithdrawlFee > 0) {
            uint256 fee = FullMath.mulDiv(_amount, config.emergencyWithdrawlFee, 1000);
            token.safeTransfer(config.feeAddress, fee);
            _amount = _amount - fee;
            emit OnFeeCharged(_lockId, msg.sender, fee);
        }
        token.safeTransfer(msg.sender, _amount);
        emit OnWithdraw(_lockId, msg.sender, _amount);
    }

    function changeConfig(uint8 tierId, uint8 multiplier, uint8 emergencyWithdrawlFee, uint8 enableEarlyWithdrawal, uint256 unlockDuration, uint8 enableRewards, address depositor, address feeAddress) external onlyOwner returns (bool) {
        config.tierId = tierId;
        config.multiplier = multiplier;
        config.emergencyWithdrawlFee = emergencyWithdrawlFee;
        config.enableEarlyWithdrawal = enableEarlyWithdrawal;
        config.unlockDuration = unlockDuration;
        config.depositor = depositor;
        config.feeAddress = feeAddress;
        config.enableRewards = enableRewards;
        return true;
    }
  
    function setDepositor(address _depositor) external onlyOwner {
        config.depositor = _depositor;
    }

    function getPoolPercentagesWithUser(address _user) external view returns(uint256, uint256) {
        return _getPoolPercentagesWithUser(_user);
    }

    function _getPoolPercentagesWithUser(address _user) internal view returns(uint256, uint256) {
        uint256 userLockIPP = 0;
        for (uint256 i = 0; i < userLocks[_user].length; i++) {
            TokenLock storage userLock = locks[userLocks[_user][i]];
            userLockIPP += userLock.iPP;
        }
        return (userLockIPP, tierTotalParticipationPoints);
    }

    // /**
    // * @notice migrates to the next locker version, only callable by lock owners
    // */
    // function migrateToNewVersion(uint256 _lockId) external nonReentrant {
    //     require(address(migrator) != address(0), "NOT SET");
    //     TokenLock storage userLock = locks[_lockId];
    //     require(userLock.owner == msg.sender, 'OWNER');
    //     uint256 amount = userLock.amount;
    //     require(amount > 0, 'AMOUNT');

    //     uint256 balance = token.balanceOf(address(this));
    //     require(amount <= balance, 'NOT ENOUGH TOKENS');
    //     token.safeApprove(address(migrator), amount);
    //     migrator.migrate(userLock.lockId, userLock.owner, userLock.amount, userLock.iPP, userLock.unlockTime, userLock.lockTime);
    //     emit OnMigrate(userLock.lockId, userLock.owner, userLock.amount, userLock.iPP, userLock.unlockTime, userLock.lockTime);
    //     userLock.amount = 0;
    //     tierTotalParticipationPoints -= userLock.iPP;
    //     userLock.iPP = 0;
    // }

    // function migrate(uint256 lockId, address owner, uint256 amount, uint256 ipp, uint256 unlockTime, uint256 lockTime) override external returns (bool) {
    //     require(allowedMigrators.contains(msg.sender), "FORBIDDEN");
    //     require(lockId > 0, 'POSITIVE LOCKID');
    //     require(owner != address(0), 'ADDRESS');
    //     require(amount > 0, 'AMOUNT');
    //     require(unlockTime > 0, 'unlockTime');
    //     require(lockTime > 0, 'lockTime');

    //     uint256 balanceBefore = token.balanceOf(address(this));
    //     token.safeTransferFrom(address(msg.sender), address(this), amount);
    //     uint256 amountIn = token.balanceOf(address(this)) - balanceBefore;
    //     require(amountIn == amount, 'NOT ENOUGH TOKEN');
    //     require(amount >= minimumDeposit, 'MIN DEPOSIT');
    //     TokenLock memory tokenLock;
    //     tokenLock.lockId = nonce;
    //     tokenLock.owner = owner;
    //     users.add(owner);
    //     tokenLock.amount = amount;
    //     tokenLock.lockTime = lockTime;
    //     tokenLock.unlockTime = unlockTime;
    //     tokenLock.iPP = ipp;
    //     // record the lock globally
    //     locks[nonce] = tokenLock;
    //     tierTotalParticipationPoints += tokenLock.iPP;
    //     userLocks[tokenLock.owner].push(tokenLock.lockId);
    //     nonce++;
    //     emit OnLock(tokenLock.lockId, tokenLock.owner, tokenLock.amount, tokenLock.iPP);
    //     return true;
    // }

    function getLockedUsersLength() external view returns(uint256) {
        return users.length();
    }

    function getLockedUserAt(uint256 _index) external view returns(address) {
        return users.at(_index);
    }

    function getMigratorsLength() external view returns(uint256) {
        return allowedMigrators.length();
    }

    function getMigratorAt(uint256 _index) external view returns(address) {
        return allowedMigrators.at(_index);
    }

    function toggleMigrator(address _migrator, uint8 add) external onlyOwner {
        if (add == 1) {
            allowedMigrators.add(_migrator);
        } else { 
            allowedMigrators.remove(_migrator);
        }
    }

    function getUserlocksLength(address _user) external view returns(uint256) {
        return userLocks[_user].length;
    }

    function changeEarlyWithdrawl(uint8 _enableEarlyWithdrawal) external onlyOwner {
        config.enableEarlyWithdrawal = _enableEarlyWithdrawal;
    }

    function changeUnlockDuration(uint8 _unlockDuration) external onlyOwner {
        config.unlockDuration = _unlockDuration;
    }  
}