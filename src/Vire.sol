// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IERC20 } from "/Users/shreya/VariableInterestRate_Model/lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { AggregatorV3Interface } from "lib/chainlink-brownie-contracts/contracts/src/v0.4/interfaces/AggregatorV3Interface.sol";
import { DynamicInterestRate } from "./DynamicInterestRate.sol";


contract Vire {
    error Vire__NeedsMoreThanZero();
    error Vire__underlyingtokenandthresholdnotmatch();
    error Vire__NotAllowedToken();
    error Vire__NotEnoughFundsToBorrow();

    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant LIQUIDITY_THRESHOLD_PERCENTAGE = 80;
    DynamicInterestRate public pidController;
     

    mapping(address token => address priceFeed) private tokenAllowedToPriceFeed;
    mapping(address user => mapping(address token => uint256 tokenamount)) private userDeposited;
    mapping(address user => mapping(address token => uint256 amount)) private userBorrower;
    mapping (address => uint256) private liquidationThresholds;


    address[] private collateralTokens;

    modifier moreThanZero(uint256 amount) {
        require(amount > 0, "Vire__NeedsMoreThanZero");
        _;
    }

    event SupplierDeposited(address indexed user, address indexed token, uint256 amount);

    modifier isAllowedToken(address token) {
        if (tokenAllowedToPriceFeed[token] == address(0)) {
            revert Vire__NotAllowedToken();
        }
        _;
    }

    constructor(address[] memory underlyingtoken, address[] memory priceFeedAddress, address[] memory threshold,  uint256 Kp,
        uint256 Ki,
        uint256 Kd,
        uint256 targetInterestRate) {
        if (underlyingtoken.length != threshold.length) {
            revert Vire__underlyingtokenandthresholdnotmatch();
        }
        for (uint256 i = 0; i < underlyingtoken.length; i++) {
            tokenAllowedToPriceFeed[underlyingtoken[i]] = priceFeedAddress[i];
            collateralTokens.push(underlyingtoken[i]);
            liquidationThresholds[underlyingtoken[i] = threshold[i]];
            pidController = new DynamicInterestRate(Kp, Ki, Kd, targetInterestRate);

        }
    }

    function DepositInPool(address tokenDepositAddress, uint256 tokenAmount) external
        moreThanZero(tokenAmount) isAllowedToken(tokenDepositAddress)
    {
        userDeposited[msg.sender][tokenDepositAddress] += tokenAmount;
        emit SupplierDeposited(msg.sender, tokenDepositAddress, tokenAmount);

        IERC20(tokenDepositAddress).transferFrom(msg.sender, address(this), tokenAmount);
    }

    function GetAccountDepositedValue(address user) public view returns (uint256) {
        uint256 totalDepositedValueinUSD = 0;

        // Loop through the tokens to get the amount they have deposited and map to price to get USD
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address token = collateralTokens[i];
            uint256 amount = userDeposited[user][token];
            totalDepositedValueinUSD += getUsdValue(token, amount);
        }

        return totalDepositedValueinUSD;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(tokenAllowedToPriceFeed[token]);
        (, int256 price,, , ) = priceFeed.latestRoundData();
        return ((amount * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

    function totalBorrowofUser(address user) internal view returns (uint256) {
     uint256 totalLoanInUsd = 0;

    for (uint256 i = 0; i < collateralTokens.length; i++) {
        address collateralType = collateralTokens[i];
        totalLoanInUsd= getUsdValue(collateralType,userBorrower[user][collateralType]);
    }

       return  totalLoanInUsd;
    }
    function updateInterestRate() internal {
       
        uint256 userDeposits = GetAccountDepositedValue(msg.sender);
        uint256 userBorrow = totalBorrowofUser(msg.sender);

        pidController.updateInterestRate(userDeposits, userBorrow);
    }


    function getLiquidationThreshold(address collateralType) public view returns (uint256) {
        return liquidationThresholds[collateralType];
    }

    function calculateLiquidityThreshold(address user) internal view returns (uint256) {
    uint256 totalCollateralValueForUser = GetAccountDepositedValue(user);

    uint256 weightedAverageLiquidationThreshold = 0;

    for (uint256 i = 0; i < collateralTokens.length; i++) {
        address collateralType = collateralTokens[i];
        uint256 collateralAmount = userDeposited[user][collateralType];
        uint256 liquidationThreshold = getLiquidationThreshold(collateralType);

        weightedAverageLiquidationThreshold += (collateralAmount * liquidationThreshold * 1e18) /
            totalCollateralValueForUser;
    } 

    return (weightedAverageLiquidationThreshold * 100) / 1e18; // converts back to percentage
    }

            
    
    function HealthFactor(address user) internal view returns(uint256){
        uint256 totalCollateralValueinUSD = GetAccountDepositedValue(user);
        uint256 totalBorrowedAmountinUSD = totalBorrowofUser(user);
        uint256  liquidityThreshold = calculateLiquidityThreshold(user);

        require(liquidityThreshold > 0,"liquidityThreshold should be greater zero");
        uint256 healthFactor = (totalCollateralValueinUSD * LIQUIDITY_THRESHOLD_PERCENTAGE/100) / totalBorrowedAmountinUSD;

        return healthFactor;
         

    }

    function canBorrow(address user) internal  view returns (bool) {
        uint256 totalCollateralValueInUSD = GetAccountDepositedValue(user);
        uint256 totalBorrowInUSD = totalBorrowofUser(user);
        uint256 liquidityThreshold = calculateLiquidityThreshold(user);

        return totalCollateralValueInUSD > totalBorrowInUSD && totalCollateralValueInUSD < liquidityThreshold;
    }
}

    

   