// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;
pragma experimental ABIEncoderV2;

interface ILeverager {
    function wethToZap(address user) external view returns (uint256);

    function ltv(address asset) external view returns (uint256);

    function zapWETHWithBorrow(
        uint256 amount,
        address borrower
    ) external returns (uint256 liquidity);

    function zapWETHWithBorrow(
        uint256 amount,
        address borrower,
        address onBehalfOf
    ) external returns (uint256 liquidity);

    function loop(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint256 borrowRatio,
        uint256 loopCount,
        bool isBorrow
    ) external;

    function loopETH(
        uint256 interestRateMode,
        uint256 borrowRatio,
        uint256 loopCount
    ) external payable;

    function wethToZapEstimation(
        address user,
        address asset,
        uint256 amount,
        uint256 borrowRatio,
        uint256 loopCount
    ) external view returns (uint256);
}
