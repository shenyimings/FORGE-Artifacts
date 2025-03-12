// SPDX-License-Identifier: None
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

contract CoLinks is Ownable {
    address public protocolFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public targetFeePercent;
    uint256 public baseFeeMax;

    event LinkTx(address holder, address target, bool isBuy, uint256 linkAmount, uint256 ethAmount, uint256 protocolEthAmount, uint256 targetEthAmount, uint256 supply);

    // LinkTarget => (Holder => Balance)
    mapping(address => mapping(address => uint256)) public linkBalance;

    // LinkTarget => Supply
    mapping(address => uint256) public linkSupply;

    function setFeeDestination(address _feeDestination) external onlyOwner {
        protocolFeeDestination = _feeDestination;
    }

    function setProtocolFeePercent(uint256 _feePercent) external onlyOwner {
        require(_feePercent <= (1 * 1 ether / 10), "Fee too high");
        protocolFeePercent = _feePercent;
    }


    function setTargetFeePercent(uint256 _feePercent) external onlyOwner {
        require(_feePercent <= (1 * 1 ether / 10), "Fee too high");
        targetFeePercent = _feePercent;
    }

    function setBaseFeeMax(uint256 _fee) external onlyOwner {
        require(_fee <= (1 ether / 1000), "Fee too high");
        baseFeeMax = _fee;
    }

    function calcBaseFee(uint256 price) private view returns (uint256) {
        uint256 fee = (price / 10);
        if (fee >= baseFeeMax) {
            return baseFeeMax;
        } else {
            return fee;
        }
    }
  
    function getPrice(uint256 supply, uint256 amount) public pure returns (uint256) {
        uint256 scaleFactor = 100;
        uint256 sum1 = supply == 0 ? 0 : ((supply - 1) * (supply) * (2 * (supply - 1) + 1) * scaleFactor) / 24;
        uint256 sum2 = supply == 0 && amount == 1 ? 0 : ((supply - 1 + amount) * (supply + amount) * (2 * (supply - 1 + amount) + 1)  * scaleFactor)/ 24;
        uint256 summation = sum2 - sum1;
        return summation * 1 ether / (16000 * scaleFactor);
    }

    function getBuyPrice(address linkTarget, uint256 amount) public view returns (uint256) {
        return getPrice(linkSupply[linkTarget], amount);
    }

    function getSellPrice(address linkTarget, uint256 amount) public view returns (uint256) {
        return getPrice(linkSupply[linkTarget] - amount, amount);
    }

    function getBuyPriceAfterFee(address linkTarget, uint256 amount) external view returns (uint256) {
        uint256 price = getBuyPrice(linkTarget, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 targetFee = price * targetFeePercent / 1 ether;

        uint256 baseFee = 0;
        if (linkSupply[linkTarget] > 0) {
            // don't add base fee to first link
            // use max fee for all buys
            baseFee = baseFeeMax;
        }
        return price + protocolFee + targetFee + baseFee;
    }

    function getSellPriceAfterFee(address linkTarget, uint256 amount) external view returns (uint256) {
        uint256 price = getSellPrice(linkTarget, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 targetFee = price * targetFeePercent / 1 ether;
        return price - protocolFee - targetFee - calcBaseFee(price);
    }

    function buyLinks(address linkTarget, uint256 amount) external payable {
        uint256 supply = linkSupply[linkTarget];
        require(supply > 0 || linkTarget == msg.sender, "Only the links' target can buy the first link");
        uint256 price = getPrice(supply, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 targetFee = price * targetFeePercent / 1 ether;

        if (supply > 0) {
            // don't add base fee to first link
            protocolFee = protocolFee + baseFeeMax / 2;
            targetFee = targetFee + baseFeeMax / 2;
        }

        require(msg.value == price + protocolFee + targetFee, "Inexact payment amount");
        linkBalance[linkTarget][msg.sender] = linkBalance[linkTarget][msg.sender] + amount;
        linkSupply[linkTarget] = supply + amount;
        emit LinkTx(msg.sender, linkTarget, true, amount, price, protocolFee, targetFee, supply + amount);
        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = linkTarget.call{value: targetFee}("");
        require(success1 && success2, "Unable to send funds");
    }

    function sellLinks(address linkTarget, uint256 amount) external payable {
        uint256 supply = linkSupply[linkTarget];
        require(supply > amount, "Cannot sell the last link");

        uint256 price = getPrice(supply - amount, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 targetFee = price * targetFeePercent / 1 ether;

        if (supply > 0) {
            // don't add base fee to first link
            uint256 baseFee = calcBaseFee(price);
            protocolFee += baseFee / 2;
            targetFee += baseFee / 2;
        }

        require(linkBalance[linkTarget][msg.sender] >= amount, "Insufficient links");
        linkBalance[linkTarget][msg.sender] = linkBalance[linkTarget][msg.sender] - amount;
        linkSupply[linkTarget] = supply - amount;
        emit LinkTx(msg.sender, linkTarget, false, amount, price, protocolFee, targetFee, supply - amount);
        (bool success1, ) = msg.sender.call{value: price - protocolFee - targetFee}("");
        (bool success2, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success3, ) = linkTarget.call{value: targetFee}("");
        require(success1 && success2 && success3, "Unable to send funds");
    }
}
