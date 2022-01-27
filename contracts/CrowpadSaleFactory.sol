// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CrowpadSale.sol";

contract CrowpadSaleFactory is Ownable {    

    address payable feeAddress;
    uint256 public deployFee = 0.8 ether;

    struct Sale {
        address saleAddress;
        address creatorAddress;
        address walletAddress;
        address token;
        uint256 rate;
        uint256 goal;
        uint256 created;
    }

    Sale[] sales;

    mapping(address => uint256) creatorSaleCount;
    mapping(address => uint256) tokenSaleCount;
    mapping(address => address) saleToCreator;
    mapping(address => address) saleToToken;

    event NewSaleCreated(address from, address wallet, address deployed);

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
    * @notice Create new sale
    * @param _rate token name
    * @param _wallet token symbol
    * @param _token The number of decimals used in token
    * @param _cap Initial supply of token
    * @param _openingTime ...
    * @param _closingTime ...
    * @param _goal ...
    * @param _releaseTime ...
    * @dev
    */
    function createSale(
        uint256 _rate,
        address payable _wallet,
        IERC20 _token,
        uint256 _cap,
        uint256 _openingTime,
        uint256 _closingTime,
        uint256 _goal,
        uint256 _releaseTime
    ) public payable {
        require(msg.value >= deployFee, 'Insufficient funds sent for deploy');
        CrowpadSale newSale = new CrowpadSale(_rate, _wallet, _token, _cap, _openingTime, _closingTime, _goal, _releaseTime);

        address saleAddress = address(newSale);
        sales.push(Sale(saleAddress, msg.sender, _wallet, address(_token), _rate, _goal, block.timestamp));

        // sales for creater
        creatorSaleCount[msg.sender]++;
        saleToCreator[saleAddress] = msg.sender;

        // sales for token
        tokenSaleCount[address(_token)]++;
        saleToToken[saleAddress] = address(_token);

        emit NewSaleCreated(msg.sender, _wallet, saleAddress);
    }

	/**
	* @notice Withdraw fee
    * @dev
    */
    function withdrawFee() external onlyOwner {
        feeAddress.transfer(address(this).balance);
    }

    /**
    * @notice Get all sales deployed on network
    * @dev
    */
    function createSale() external view returns (Sale[] memory) {
        return sales;
    }

    /**
    * @notice Get all sales of given user
    * @param _user user address
    * @dev
    */
    function getUserSales(address _user) external view returns (Sale[] memory) {
        Sale[] memory result = new Sale[](creatorSaleCount[_user]);
        uint counter = 0;

        for (uint i = 0; i < sales.length; i++) {
            if (saleToCreator[sales[i].saleAddress] == _user) {
                result[counter] = sales[i];
                counter++;
            }
        }
        return result;
    }

    /**
    * @notice Get all sales of given token
    * @param _tokenAddress token address
    * @dev
    */
    function getTokenSales(address _tokenAddress) external view returns (Sale[] memory) {
        Sale[] memory result = new Sale[](tokenSaleCount[_tokenAddress]);
        uint counter = 0;

        for (uint i = 0; i < sales.length; i++) {
            if (saleToToken[sales[i].saleAddress] == _tokenAddress) {
                result[counter] = sales[i];
                counter++;
            }
        }
        return result;
    }
}