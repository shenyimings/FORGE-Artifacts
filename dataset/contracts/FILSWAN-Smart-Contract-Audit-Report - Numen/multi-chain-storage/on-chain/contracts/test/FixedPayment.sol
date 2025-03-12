// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./USDCoin.sol";

contract FixedPayment is Ownable{
    USDCoin USDC;
    uint public price;

    mapping(string => uint) paymentMap;

    event MakePayment(address payer, string wcid, uint price);
    event PriceChange(uint newPrice);

    constructor(address usdc, uint initialPrice) {
        USDC = USDCoin(usdc);
        price = initialPrice;
    }

    function makePayment(string memory wCid) public {
        require(paymentMap[wCid] == 0, "CID: already paid");
        require(USDC.allowance(msg.sender, address(this)) >= price, "ERC20: allowance to low");
        
        paymentMap[wCid] = price;
        USDC.transferFrom(msg.sender, address(this), price);

        emit MakePayment(msg.sender, wCid, price);
    }

    function setPrice(uint newPrice) public onlyOwner { 
        price = newPrice;
        emit PriceChange(newPrice);
    }

    function withdraw(uint amount) public onlyOwner {
        require(amount <= USDC.balanceOf(address(
            this)), "withdraw amount too high");
        USDC.transfer(msg.sender, amount);
    }

    // getter functions
    function getUSDCAddress() public view returns(address) {
        return address(USDC);
    }

}