// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IBEP20.sol";
import "../libraries/SafeBEP20.sol";
import "../interfaces/IRandomGenerator.sol";
import "../interfaces/IDice.sol";

contract MockRandomGenerator is IRandomGenerator, Ownable {
    using SafeBEP20 for IBEP20;

    IDice public dice;
    uint256 public lastRequestId;

    /**
     * @notice Request randomness
     */
    function getRandomNumber() external override returns (uint256) {
        lastRequestId = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty)));
        return lastRequestId;
    }

    /**
     * @notice Set the address for the LuckyNumber
     * @param _diceAddr: address of the LuckyNumber
     */
    function setDice(address _diceAddr) external onlyOwner {
        dice = IDice(_diceAddr);
    }

    /**
     * @notice It allows the admin to withdraw tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: the number of token amount to withdraw
     * @dev Only callable by owner.
     */
    function withdrawTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        IBEP20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);
    }

    /**
     * @notice Callback function used by ChainLink's VRF Coordinator
     */
    function fulfillRandomness(uint256 requestId, uint256 randomness) external onlyOwner {
        dice.sendSecret(requestId, randomness);
    }
}