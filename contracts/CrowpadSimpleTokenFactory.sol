// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CrowpadSimpleToken.sol";

contract CrowpadSimpleTokenFactory is Ownable {

    address payable feeAddress;
    uint256 public deployFee = 0.8 ether;

    struct Token {
        address tokenAddress;
        address creatorAddress;
        address initialSuppliedAccount;
        bytes32 name;
        bytes32 symbol;
        uint8 decimals;
        uint256 supply;
        uint256 created;
    }

    Token[] tokens;

    mapping(address => uint256) creatorTokenCount;
    mapping(address => address) tokenToCreator;

    event NewTokenCreated(address from, address suppliedAccount, address deployed);

    constructor(address payable _feeAddress) {
        feeAddress = _feeAddress;
    }

    function setDeployFee(uint256 _newDeployFee) external onlyOwner {
        deployFee = _newDeployFee;
    }

    /**
    * @notice Set address in which fee is stored
    * @param _newAddress new address
    * @dev
    */
    function setFeeAddress(address payable _newAddress) external onlyOwner {
        feeAddress = _newAddress;
    }
    
    /**
    * @notice Create new token
    * @param _name token name
    * @param _symbol token symbol
    * @param _decimals The number of decimals used in token
    * @param _supply Initial supply of token
    * @param _initialSuppliedAccount Account address to which initial supply is deposited
    * @dev
    */
    function createNewToken(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _supply,
        address _initialSuppliedAccount
    ) public payable {
        require(msg.value >= deployFee, 'Insufficient funds sent for deploy');
        CrowpadSimpleToken newToken = new CrowpadSimpleToken(_name, _symbol, _decimals, _supply, _initialSuppliedAccount);

        address tokenAddress = address(newToken);

        tokens.push(Token(tokenAddress, msg.sender, _initialSuppliedAccount, keccak256(abi.encode(_name)), keccak256(abi.encode(_symbol)), _decimals, _supply, block.timestamp));
        creatorTokenCount[msg.sender]++;
        tokenToCreator[tokenAddress] = msg.sender;

        emit NewTokenCreated(msg.sender, _initialSuppliedAccount, tokenAddress);
    }

    /**
    * @notice Withdraw fee
    * @dev
    */
    function withdrawFee() external onlyOwner {
        feeAddress.transfer(address(this).balance);
    }

    /**
    * @notice Get all tokens deployed on network
    * @dev
    */
    function getAllTokens() external view returns (Token[] memory) {
        return tokens;
    }

    /**
    * @notice Get all tokens of given user
    * @param _user user address
    * @dev
    */
    function getUserTokens(address _user) external view returns (Token[] memory) {
        Token[] memory result = new Token[](creatorTokenCount[_user]);
        uint counter = 0;

        for (uint i = 0; i < tokens.length; i++) {
            if (tokenToCreator[tokens[i].tokenAddress] == _user) {
                result[counter] = tokens[i];
                counter++;
            }
        }
        return result;
    }
}
