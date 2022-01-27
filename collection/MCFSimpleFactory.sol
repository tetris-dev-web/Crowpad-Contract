import "./MyMCFcoinsimple.sol";

pragma solidity ^0.8.4;
// SPDX-License-Identifier: Unlicensed


abstract contract ReentrancyGuard {

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }


    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

abstract contract Roles{
    address public _owner;
    address private _previousOwner;
    uint256 public _lockTime;
    constructor(){
        _setOwner(msg.sender);
    }
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }


    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }


        //Locks the contract for owner for the amount of time provided
    function lock(uint256 time) public virtual onlyOwner {
        _previousOwner = _owner;
        _owner = address(0);
        _lockTime = time;
        emit OwnershipTransferred(_owner, address(0));
    }

    //Unlocks the contract for owner when _lockTime is exceeds
    function unlock() public virtual {
        require(_previousOwner == msg.sender, "You don't have permission to unlock.");
        require(block.timestamp > _lockTime , "Contract is locked.");
        emit OwnershipTransferred(_owner, _previousOwner);
        _owner = _previousOwner;
    }
     function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


contract MCFSimpleFactory is Roles, ReentrancyGuard{
    address payable feesAddress;
    uint256 public deployFee = 0.8 ether;

    event ContractDeployed(address from, address owner, address deployed);

    function setDeployFee(uint256 newDeployFee_) external onlyOwner{
        deployFee = newDeployFee_;
    }

    function deployNewInstance(string memory _NAME, string memory _SYMBOL, uint256 _DECIMALS,
        uint256 _supply, address routerAddress, address tokenOwner) public payable{
        require(msg.value >= deployFee, 'Insufficient funds sent for deploy');
        myBasicMCFCoin newInstance = new myBasicMCFCoin(_NAME,_SYMBOL,_DECIMALS,_supply, routerAddress, tokenOwner);

        emit ContractDeployed(msg.sender, tokenOwner, address(newInstance));
    }

    function withdrawFees() external onlyOwner{
        uint256 currentContractBalance = address(this).balance;
        feesAddress.transfer(currentContractBalance);

    }

    function updateFeeAddress(address payable newAddress) external onlyOwner{
        feesAddress=newAddress;
    }
}
