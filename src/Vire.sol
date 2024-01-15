// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors 
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Vire {

    error Vire__NeedsMoreThanZero();
    error Vire__underlyingtokenandpriceFeedonotmatch();
    error Vire__NotAllowedToken();

    mapping (address token => address priceFeed) private tokenAllowedToPriceFeed;
    mapping(address user => mapping(address token => uint256 amount)) private userDeposited;
    modifier moreThanZero(uint256 amount) {
        if(amount == 0){
          revert Vire__NeedsMoreThanZero(); 
        }
        _;   
    }

    event SupplierDeposited(address indexed user, address indexed token, uint256 amount);

    modifier isAllowedToken(address token) {
        if(tokenAllowedToPriceFeed[token] == address(0)){
           revert Vire__NotAllowedToken();
        }
        _;
    }

    constructor(address[] memory underlyingtoken, address[] memory priceFeedAddress) {
        if( underlyingtoken.length!= priceFeedAddress.length){
            revert Vire__underlyingtokenandpriceFeedonotmatch();
        }
        for(uint256 i =0; i<underlyingtoken.length; i++){
            tokenAllowedToPriceFeed[underlyingtoken[i]] = priceFeedAddress[i];

        }
    }


    function DepositInPool(address tokenDepositAddress, uint256 tokenAmount) external 
      moreThanZero(tokenAmount)isAllowedToken(tokenDepositAddress) {
        userDeposited[msg.sender][tokenDepositAddress] += tokenAmount;
        emit SupplierDeposited(msg.sender, tokenDepositAddress, tokenAmount);
        

    }


}