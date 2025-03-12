// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract RiskModel {
    struct RiskItem {
        uint256 interestRate;
        uint256 advanceRate;
    }

    mapping(string => RiskItem) riskData;
    address private owner;
    
    constructor(address owner_) {
        owner = owner_;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function addRiskItem(string memory rating, uint256 interestRate, uint256 advanceRate) public onlyOwner {
        riskData[rating] = RiskItem(interestRate, advanceRate);
    }

    function updateRiskItem(string memory rating, uint256 interestRate, uint256 advanceRate) public onlyOwner {
        riskData[rating].interestRate = interestRate;
        riskData[rating].advanceRate = advanceRate;
    }

    function removeRiskItem(string memory rating) public onlyOwner {
        delete riskData[rating];
    }

    function getRiskInterestRate(string memory rating) external view returns (uint256) {
        return riskData[rating].interestRate;
    } 

    function getRiskAdvanceRate(string memory rating) external view returns (uint256) {
        return riskData[rating].advanceRate;
    }
}