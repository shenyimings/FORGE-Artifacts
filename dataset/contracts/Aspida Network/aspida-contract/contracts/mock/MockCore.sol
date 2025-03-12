// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../interface/ICore.sol";

/**
 * @title Aspida's ether MockCore
 * @author Aspida engineer
 */
contract MockCore is ICore {
    function receiveStrategyEarning() external payable override {}

    function strategyMinting(address _receiver, uint256 _amount) external pure override {
        _receiver;
        _amount;
    }

    function supplyReward(uint256 _amount) external pure override {
        _amount;
    }

    function dETH() external pure override returns (address) {
        return address(0);
    }
}
