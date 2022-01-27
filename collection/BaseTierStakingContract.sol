// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./TransferHelper.sol";
import './FullMath.sol';

import "./EnumerableSet.sol";
import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./IERC20.sol";

interface IMigrator {
    function migrate(uint256 lockId, address owner, uint256 amount, uint256 ipp, uint256 unlockTime,  uint256 lockTime) external returns (bool);
}
interface IStakingHelper{
    function isWithdrawlAllowed() external view returns (bool);
}

contract BaseTierStakingContract is Ownable, ReentrancyGuard, IMigrator {
  using EnumerableSet for EnumerableSet.AddressSet;
  uint256 public CONTRACT_VERSION = 1;
  
  struct TokenLock{
    uint256 lockId;
    address owner;
    uint256 amount;
    uint256 iPP; // individual pool percentage
    uint256 unlockTime;
    uint256 lockTime;
  }
  struct Config{
    uint8 tierId; //0 based index
    uint8 multiplier; // in 10 to support single decimal such as 0.1 and 1.2
    uint8 emergencyWithdrawlFee; // in 1000 so for 2% fee it will be 20
    uint8 enableEarlyWithdrawal;
    uint8 enableRewards;
    uint256 unlockDuration; // epoch timestamp
    address depositor;  // Depositor contract who is allowed to stake
    address feeAddress; // Address to receive the fee
    address stakingHelper; // Address of the staking helper contract
  }

  struct LockParams {
    address payable owner; // the user who can withdraw tokens once the lock expires.
    uint256 amount; // amount of tokens to lock
  }

  EnumerableSet.AddressSet private USERS; 
  EnumerableSet.AddressSet private allowedMigrators; // Address of the contract that can migrate the tokens
  uint256 public tierTotalParticipationPoints;
  uint256 public NONCE = 1; // incremental lock nonce counter, this is the unique ID for the next lock
  uint256 public MINIMUM_DEPOSIT = 1000* (10 ** 18); // minimum divisibility per lock at time of locking
  address public tokenAddress; // the token address

  Config public CONFIG;
  mapping(uint256 => TokenLock) public LOCKS; // map lockId nonce to the lock
  mapping(address => uint256[]) public USER_LOCKS; // UserAddress=> LockId
  
  IMigrator public MIGRATOR;
  event onLock(uint256 lockId, address owner, uint256 amountInTokens, uint256 iPP);
  event onLockUpdated(uint256 lockId, address owner, uint256 amountInTokens, uint256 tierId);
  event onWithdraw(uint256 lockId, address owner, uint256 amountInTokens);
  event onFeeCharged(uint256 lockId, address owner, uint256 amountInTokens);
  event onMigrate(uint256 lockId, address owner, uint256 amount, uint256 ipp, uint256 unlockTime,  uint256 lockTime);

  
  constructor (uint8 tierId, uint8 multiplier, uint8 emergencyWithdrawlFee, uint8 enableEarlyWithdrawal, uint256 unlockDuration, uint8 enableRewards, address _depositor, address _tokenAddress, address _feeAddress, address _stakingHelper) public {
    tokenAddress = _tokenAddress;
    CONFIG.tierId = tierId;
    CONFIG.multiplier = multiplier;
    CONFIG.emergencyWithdrawlFee = emergencyWithdrawlFee;
    CONFIG.unlockDuration = unlockDuration;
    CONFIG.enableEarlyWithdrawal = enableEarlyWithdrawal;
    CONFIG.depositor = _depositor;
    CONFIG.stakingHelper  = _stakingHelper;
    CONFIG.feeAddress = _feeAddress;
    CONFIG.enableRewards = enableRewards;
  }
  

  /**
   * @notice set the migrator contract which allows the lock to be migrated
   */
  function setMigrator(IMigrator _migrator) external onlyOwner {
    MIGRATOR = _migrator;
  }
  

/**
   * @notice Creates one or multiple locks for the specified token
   * @param _owner the owner of the lock
   * @param _amount amount of the lock
   * owner: user or contract who can withdraw the tokens
   * amount: must be >= 100 units
   * Fails is amount < 100
   */
  function singleLock (address payable _owner, uint256 _amount) external  {
    LockParams memory param = LockParams(_owner, _amount);
    LockParams[] memory params = new LockParams[](1);
    params[0] = param;
    _lock(params);
  }
  
  function _lock(LockParams[] memory _lock_params) internal nonReentrant{
    require(msg.sender == CONFIG.depositor, 'Only depositor can call this function');
    require(_lock_params.length > 0, 'NO PARAMS');
    uint256 totalAmount = 0;
    for (uint256 i = 0; i < _lock_params.length; i++) {
        require(_lock_params[i].owner!=address(0), 'No ADDR');
        require(_lock_params[i].amount>0, 'No AMT');
        totalAmount += _lock_params[i].amount;
    }

    uint256 balanceBefore = IERC20(tokenAddress).balanceOf(address(this));
    TransferHelper.safeTransferFrom(tokenAddress, address(msg.sender), address(this), totalAmount);
    uint256 amountIn = IERC20(tokenAddress).balanceOf(address(this)) - balanceBefore;
    require(amountIn == totalAmount, 'NOT ENOUGH TOKEN');
    for (uint256 i = 0; i < _lock_params.length; i++) {
        LockParams memory lock_param = _lock_params[i];
        require(lock_param.amount >= MINIMUM_DEPOSIT, 'MIN DEPOSIT');
        TokenLock memory token_lock;
        token_lock.lockId = NONCE;
        token_lock.owner = lock_param.owner;
        USERS.add(lock_param.owner);
        token_lock.amount = lock_param.amount;
        token_lock.lockTime = block.timestamp;
        token_lock.unlockTime = block.timestamp + CONFIG.unlockDuration;
        token_lock.iPP = lock_param.amount * CONFIG.multiplier;
        // record the lock globally
        LOCKS[NONCE] = token_lock;
        tierTotalParticipationPoints += token_lock.iPP;
        USER_LOCKS[token_lock.owner].push(token_lock.lockId);
        NONCE ++;
        emit onLock(token_lock.lockId, token_lock.owner, token_lock.amount, token_lock.iPP);
    }
  }
  /**
   * @notice Creates one or multiple locks
   * @param _lock_params an array of locks with format: [LockParams[owner, amount]]
   * owner: user or contract who can withdraw the tokens
   * amount: must be >= 100 units
   * Fails is amount < 100
   */
  
  function lock (LockParams[] memory _lock_params) external{
    _lock( _lock_params);
  }
  
   /**
   * @notice withdraw a specified amount from a lock. _amount is the ideal amount to be withdrawn.
   * however, this amount might be slightly different in rebasing tokens due to the conversion to shares,
   * then back into an amount
   * @param _lockId the lockId of the lock to be withdrawn
   */
  function withdraw ( uint256 _lockId, uint256 _index, uint256 _amount) external nonReentrant {
    require(IStakingHelper(CONFIG.stakingHelper).isWithdrawlAllowed(), 'NOT ALLOWED');
    TokenLock storage userLock = LOCKS[_lockId];
    require(userLock.unlockTime <= block.timestamp ||  CONFIG.enableEarlyWithdrawal == 1, 'Early withdrawal is disabled');
    require(USER_LOCKS[msg.sender].length > _index, 'Index OOB');
    require(USER_LOCKS[msg.sender][_index] == _lockId, 'lockId NOT MATCHED');
    require(userLock.owner == msg.sender, 'OWNER');
    uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
    uint256 withdrawableAmount = LOCKS[_lockId].amount;
    require(withdrawableAmount > 0, 'NO TOKENS');
    require(_amount <= withdrawableAmount, 'AMOUNT<WAMNT');
    require(_amount <= balance, 'NOT ENOUGH TOKENS');
    LOCKS[_lockId].amount = withdrawableAmount-_amount;
    uint256 decreaseIPP = _amount * CONFIG.multiplier;
    tierTotalParticipationPoints -= decreaseIPP;
    LOCKS[_lockId].iPP -= decreaseIPP;
    if(userLock.unlockTime> block.timestamp && CONFIG.emergencyWithdrawlFee>0){
      uint256 fee = FullMath.mulDiv(_amount,CONFIG.emergencyWithdrawlFee , 1000);
      TransferHelper.safeTransfer(tokenAddress, CONFIG.feeAddress, fee);
      _amount = _amount - fee;
      emit onFeeCharged(_lockId, msg.sender, fee);
    }
    TransferHelper.safeTransfer(tokenAddress, msg.sender, _amount);
    emit onWithdraw(_lockId, msg.sender, _amount);
  }
  function changeConfig( uint8 tierId, uint8 multiplier, uint8 emergencyWithdrawlFee, uint8 enableEarlyWithdrawal, uint256 unlockDuration, uint8 enableRewards, address depositor, address feeAddress)  external onlyOwner returns(bool) {
    CONFIG.tierId = tierId;
    CONFIG.multiplier = multiplier;
    CONFIG.emergencyWithdrawlFee = emergencyWithdrawlFee;
    CONFIG.enableEarlyWithdrawal = enableEarlyWithdrawal;
    CONFIG.unlockDuration = unlockDuration;
    CONFIG.depositor = depositor;
    CONFIG.feeAddress = feeAddress;
    CONFIG.enableRewards = enableRewards;
    return true;
  }
  
  function setDepositor(address _depositor) external onlyOwner {
    CONFIG.depositor = _depositor;
  }
  function setStakingHelper(address _stakingHelper) external onlyOwner {
    CONFIG.stakingHelper = _stakingHelper;
  }
  function getPoolPercentagesWithUser(address _user) external view returns(uint256, uint256){
    return _getPoolPercentagesWithUser(_user);
  }

  function _getPoolPercentagesWithUser(address _user) internal view returns(uint256, uint256){
    uint256 userLockIPP = 0;
    for(uint256 i = 0; i<USER_LOCKS[_user].length; i++){
      TokenLock storage userLock = LOCKS[USER_LOCKS[_user][i]];
      userLockIPP += userLock.iPP;
    }
    return (userLockIPP, tierTotalParticipationPoints);
  }
  /**
   * @notice migrates to the next locker version, only callable by lock owners
   */
  function migrateToNewVersion (uint256 _lockId) external nonReentrant{
    require(address(MIGRATOR) != address(0), "NOT SET");
    TokenLock storage userLock = LOCKS[_lockId];
    require(userLock.owner == msg.sender, 'OWNER');
    uint256 amount = userLock.amount;
    require(amount > 0, 'AMOUNT');

    uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
    require(amount <= balance, 'NOT ENOUGH TOKENS');
    TransferHelper.safeApprove(tokenAddress, address(MIGRATOR), amount);
    MIGRATOR.migrate(userLock.lockId, userLock.owner, userLock.amount, userLock.iPP, userLock.unlockTime,userLock.lockTime);
    emit onMigrate(userLock.lockId, userLock.owner, userLock.amount, userLock.iPP, userLock.unlockTime,userLock.lockTime);
    userLock.amount = 0;
    tierTotalParticipationPoints -= userLock.iPP;
    userLock.iPP = 0;
  }

   function migrate (uint256 lockId, address owner, uint256 amount, uint256 ipp, uint256 unlockTime,  uint256 lockTime) override external returns(bool) {
    require(allowedMigrators.contains(msg.sender), "FORBIDDEN");
    require(lockId > 0, 'POSITIVE LOCKID');
    require(owner != address(0), 'ADDRESS');
    require(amount > 0, 'AMOUNT');
    require(unlockTime > 0, 'unlockTime');
    require(lockTime > 0, 'lockTime');

    uint256 balanceBefore = IERC20(tokenAddress).balanceOf(address(this));
    TransferHelper.safeTransferFrom(tokenAddress, address(msg.sender), address(this), amount);
    uint256 amountIn = IERC20(tokenAddress).balanceOf(address(this)) - balanceBefore;
    require(amountIn == amount, 'NOT ENOUGH TOKEN');
    require(amount >= MINIMUM_DEPOSIT, 'MIN DEPOSIT');
    TokenLock memory token_lock;
    token_lock.lockId = NONCE;
    token_lock.owner = owner;
    USERS.add(owner);
    token_lock.amount = amount;
    token_lock.lockTime = lockTime;
    token_lock.unlockTime = unlockTime;
    token_lock.iPP = ipp;
    // record the lock globally
    LOCKS[NONCE] = token_lock;
    tierTotalParticipationPoints += token_lock.iPP;
    USER_LOCKS[token_lock.owner].push(token_lock.lockId);
    NONCE ++;
    emit onLock(token_lock.lockId, token_lock.owner, token_lock.amount, token_lock.iPP);
    return true;
  }

  function getLockedUsersLength() external view returns(uint256){
    return USERS.length();
  }
  function getLockedUserAt(uint256 _index) external view returns(address){
    return USERS.at(_index);
  }
  function getMigratorsLength() external view returns(uint256){
    return allowedMigrators.length();
  }
  function getMigratorAt(uint256 _index) external view returns(address){
    return allowedMigrators.at(_index);
  }
  function toggleMigrator(address _migrator, uint8 add) external onlyOwner {
    if(add == 1){
      allowedMigrators.add(_migrator);
    }
    else { 
      allowedMigrators.remove(_migrator);
    }
  }

  function getUserLocksLength(address _user) external view returns(uint256){
    return USER_LOCKS[_user].length;
  }
  function changeEarlyWithdrawl(uint8 _enableEarlyWithdrawal) external onlyOwner {
    CONFIG.enableEarlyWithdrawal = _enableEarlyWithdrawal;
  }
  function changeUnlockDuration(uint8 _unlockDuration) external onlyOwner {
    CONFIG.unlockDuration = _unlockDuration;
  }
  
}