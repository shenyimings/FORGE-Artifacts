// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/**
 * @dev Interface for VAI Controller
 */
interface IVAIController {

    function mintVAI(uint mintVAIAmount) external returns (uint256);

    function repayVAI(uint repayVAIAmount) external returns (uint256);

    function getMintableVAI(address minter) external view returns (uint256, uint256);
}