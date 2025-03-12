// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IInterestRate {
    function calculate(uint256 principal, uint256 beginSubscriptionBlock, uint256 endSubscriptionBlock, uint256 beginBlock, uint256 endBlock) external view returns (uint256);

    function nowAPR(uint256 beginSubscriptionBlock, uint256 endSubscriptionBlock) external view returns (string memory);
}