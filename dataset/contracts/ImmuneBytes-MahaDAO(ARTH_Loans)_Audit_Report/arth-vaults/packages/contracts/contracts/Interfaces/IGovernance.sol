// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../Dependencies/IERC20.sol";
import "./IPriceFeed.sol";
import "../Dependencies/IUniswapPairOracle.sol";

interface IGovernance {
    function getMaxDebtCeiling() external view returns (uint256);

    function getAllowMinting() external view returns (bool);

    function getPriceFeed() external view returns (IPriceFeed);

    function getStabilityFee() external view returns (uint256);

    function getStabilityFeeToken() external view returns (IERC20);

    function getStabilityTokenPairOracle() external view returns (IUniswapPairOracle);

    function chargeStabilityFee(address who, uint256 LUSDAmount) external;
}
