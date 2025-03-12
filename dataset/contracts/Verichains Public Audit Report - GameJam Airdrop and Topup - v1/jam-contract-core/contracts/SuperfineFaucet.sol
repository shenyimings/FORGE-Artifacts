// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SuperfineFaucet is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;

    uint256 public faucetAmount;
    uint256 public faucetInterval;
    mapping(address => uint256) lastFaucet;

    constructor() {}

    receive() external payable {}

    function getLastFaucet(address client) external view returns (uint256) {
        return lastFaucet[client];
    }

    function setFaucetAmount(uint256 faucetAmount_) external onlyOwner {
        faucetAmount = faucetAmount_;
    }

    function setFaucetInterval(uint256 faucetInterval_) external onlyOwner {
        faucetInterval = faucetInterval_;
    }

    function faucet(
        address[] memory recipients
    ) external nonReentrant whenNotPaused {
        require(
            address(this).balance > faucetAmount.mul(recipients.length),
            "SuperfineFaucet: not enough balance"
        );
        for (uint256 i = 0; i < recipients.length; i++)
            if (block.timestamp > lastFaucet[recipients[i]] + faucetInterval) {
                lastFaucet[recipients[i]] = block.timestamp;
                (bool success, ) = payable(recipients[i]).call{
                    value: faucetAmount
                }("");
                require(success, "SuperfineFaucet: faucet failed");
            }
    }

    function pauseFaucet() external onlyOwner {
        _pause();
    }

    function unpauseFaucet() external onlyOwner {
        _unpause();
    }
}
