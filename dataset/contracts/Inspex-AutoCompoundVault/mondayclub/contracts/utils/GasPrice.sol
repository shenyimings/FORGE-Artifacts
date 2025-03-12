// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";

contract GasPrice is Ownable {
    uint256 public maxGasPrice = 5000000000;

    event NewMaxGasPrice(uint256 oldPrice, uint256 newPrice);

    function setMaxGasPrice(uint256 _maxGasPrice) external onlyOwner {
        maxGasPrice = _maxGasPrice;
        emit NewMaxGasPrice(maxGasPrice, _maxGasPrice);
    }
}