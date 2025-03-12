// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface ICurveProxy {
    function crvFeePct() external view returns (uint256);

    function setPerGaugeApproval(address caller, address gauge) external returns (bool);

    function withdrawFromGauge(address gauge, address lpToken, uint amount, address receiver) external returns (bool);

    function mintCRV(address gauge, address receiver) external returns (uint256);
}
