// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../strategy/model/StrategyBase.sol";

/**
 * @title Aspida's ether MockStrategy
 * @author Aspida engineer
 */
contract MockStrategy is StrategyBase {
    constructor(ICore _core) StrategyBase(_core) {}

    function strategyReceive() external payable override onlyCore returns (uint256) {}

    function repayCore() external {
        CORE.receiveStrategyEarning{ value: address(this).balance }();
    }

    function strategyMinting(address _receiver, uint256 _amount) external {
        CORE.strategyMinting(_receiver, _amount);
    }
}
