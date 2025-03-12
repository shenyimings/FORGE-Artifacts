pragma solidity ^0.8.0;

import "../../../contracts/yield/module/StargateYieldModule.sol";

contract StargateYieldModuleDeltaCreditMock is StargateYieldModule {
    uint256 deltaCredit = 0;

    function _poolDeltaCredit() override internal view returns (uint256) {
        return deltaCredit;
    }

    function setPoolDeltaCredit(uint256 _deltaCredit) external {
        deltaCredit = _deltaCredit;
    }
}