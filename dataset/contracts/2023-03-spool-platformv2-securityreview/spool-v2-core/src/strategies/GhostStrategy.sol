// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../interfaces/IStrategy.sol";

contract GhostStrategy is IERC20Upgradeable, IStrategy {
    constructor() {}

    function strategyName() external pure returns (string memory) {
        return "Ghost strategy";
    }

    function totalUsdValue() external pure returns (uint256) {
        return 0;
    }

    function assetRatio() external pure returns (uint256[] memory) {
        return new uint256[](0);
    }

    function assetGroupId() external pure returns (uint256) {
        return 0;
    }

    function assets() external pure returns (address[] memory) {
        return new address[](0);
    }

    function doHardWork(StrategyDhwParameterBag calldata) external pure returns (DhwInfo memory) {
        revert IsGhostStrategy();
    }

    function claimShares(address, uint256) external pure {
        revert IsGhostStrategy();
    }

    function releaseShares(address, uint256) external pure {
        revert IsGhostStrategy();
    }

    function redeemFast(
        uint256,
        address,
        address[] calldata,
        uint256[] calldata,
        IUsdPriceFeedManager,
        uint256[] calldata
    ) external pure returns (uint256[] memory) {
        revert IsGhostStrategy();
    }

    function redeemShares(
        uint256,
        address,
        address[] calldata,
        uint256[] calldata,
        IUsdPriceFeedManager,
        uint256[] calldata
    ) external pure returns (uint256[] memory) {
        revert IsGhostStrategy();
    }

    function depositFast(
        address[] calldata,
        uint256[] calldata,
        IUsdPriceFeedManager,
        uint256[] calldata,
        SwapInfo[] calldata
    ) external pure returns (uint256) {
        revert IsGhostStrategy();
    }

    function totalSupply() external pure returns (uint256) {
        return 0;
    }

    function balanceOf(address) external pure returns (uint256) {
        return 0;
    }

    function transfer(address, uint256) external pure returns (bool) {
        revert IsGhostStrategy();
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external pure returns (bool) {
        revert IsGhostStrategy();
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        revert IsGhostStrategy();
    }

    function beforeDepositCheck(uint256[] memory, uint256[] calldata) external pure {
        revert IsGhostStrategy();
    }

    function beforeRedeemalCheck(uint256, uint256[] calldata) external pure {
        revert IsGhostStrategy();
    }

    function emergencyWithdraw(uint256[] calldata, address) external pure {
        revert IsGhostStrategy();
    }
}
