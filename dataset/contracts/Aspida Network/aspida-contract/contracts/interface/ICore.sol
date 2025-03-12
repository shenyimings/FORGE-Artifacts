// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface ICore {
    function receiveStrategyEarning() external payable;

    function strategyMinting(address _receiver, uint256 _amount) external;

    function supplyReward(uint256 _amount) external;

    function dETH() external view returns (address);
}
