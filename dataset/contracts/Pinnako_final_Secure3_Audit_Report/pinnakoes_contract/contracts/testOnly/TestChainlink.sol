// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../oracle/interfaces/AggregatorV3Interface.sol";

contract TestChainLink is AggregatorV3Interface, Ownable{
    using SafeMath for uint256;

    uint8 public constant PRICE_DECIMAL = 8;
    
    int256 public tokenPrice = 0;
    uint256 public tokenUpdateAt = 0;
    uint256 public tokenStartAt = 0;
    constructor() {
    }

    function decimals() public override pure returns(uint8){
        return PRICE_DECIMAL;
    }

    function description() public override pure returns (string memory){
        return "";
    }

    function version() public override pure returns (uint256){
        return 0;
    }


    function setPrice(int256 set_price) external onlyOwner{
        tokenPrice = set_price;
        tokenUpdateAt = block.timestamp;
        tokenStartAt =  block.timestamp;
    }


    function latestRoundData() public override view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ){
        roundId = 1;
        answer = tokenPrice;
        startedAt = tokenStartAt;
        updatedAt = tokenUpdateAt;
        answeredInRound = 1;       
    }
   
}
