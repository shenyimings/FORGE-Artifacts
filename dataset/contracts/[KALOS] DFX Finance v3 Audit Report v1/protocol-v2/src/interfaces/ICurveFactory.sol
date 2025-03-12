// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IAssimilatorFactory.sol";

interface ICurveFactory {
    function getProtocolFee() external view returns (int128);

    function getProtocolTreasury() external view returns (address);

    function assimilatorFactory() external view returns (IAssimilatorFactory);

    function wETH() external view returns (address);

    function isDFXCurve(address) external view returns (bool);
}
