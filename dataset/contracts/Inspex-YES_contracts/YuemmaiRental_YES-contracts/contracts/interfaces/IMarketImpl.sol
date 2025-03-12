//SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0;

interface IMarketImpl {
    function marketBuy(address market, address srcToken, address destToken, uint amount, address payable beneficiary, uint slippageTolerrance) external payable returns (uint);
    function merketSell(address market, address srcToken, address destToken, uint amount, address payable beneficiary, uint slippageTolerrance) external returns (uint);
}