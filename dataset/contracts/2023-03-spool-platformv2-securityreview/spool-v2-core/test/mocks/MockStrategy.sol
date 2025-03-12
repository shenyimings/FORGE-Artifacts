// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/utils/math/Math.sol";
import "../../src/strategies/Strategy.sol";

contract MockStrategy is Strategy {
    using SafeERC20 for IERC20;

    uint256[] public ratios;
    uint256[] public __withdrawnAssets;
    bool public __withdrawnAssetsSet;
    uint256 public depositFee;
    uint256 public withdrawalFee;

    ISwapper _swapper;
    MockProtocol public protocol;
    MockProtocol public protocolFees;

    constructor(
        string memory name_,
        IAssetGroupRegistry assetGroupRegistry_,
        ISpoolAccessControl accessControl_,
        ISwapper swapper_
    ) Strategy(name_, assetGroupRegistry_, accessControl_) {
        _swapper = swapper_;
        protocol = new MockProtocol();
        protocolFees = new MockProtocol();
    }

    function initialize(uint256 assetGroupId_, uint256[] memory ratios_) external initializer {
        __Strategy_init(assetGroupId_);

        ratios = ratios_;
    }

    function assetRatio() external view override returns (uint256[] memory) {
        return ratios;
    }

    function setTotalUsdValue(uint256 totalUsdValue_) external {
        totalUsdValue = totalUsdValue_;
    }

    function _getYieldPercentage(int256 manualYield) internal pure override returns (int256) {
        return manualYield;
    }

    function _compound(address[] calldata tokens, SwapInfo[] calldata compoundSwapInfo, uint256[] calldata slippages)
        internal
        override
        returns (int256 compoundYield)
    {}

    function _swapAssets(address[] memory tokens, uint256[] memory toSwap, SwapInfo[] calldata swapInfo)
        internal
        override
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransfer(address(_swapper), toSwap[i]);
        }

        _swapper.swap(tokens, swapInfo, tokens, address(this));
    }

    function _depositToProtocol(address[] calldata tokens, uint256[] memory amounts, uint256[] calldata)
        internal
        override
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            // deposit fees
            IERC20(tokens[i]).safeTransfer(address(protocolFees), amounts[i] * depositFee / 100_00);
            // deposit
            IERC20(tokens[i]).safeTransfer(address(protocol), amounts[i] * (100_00 - depositFee) / 100_00);
        }
    }

    function _getUsdWorth(uint256[] memory exchangeRates, IUsdPriceFeedManager priceFeedManager)
        internal
        view
        override
        returns (uint256)
    {
        address[] memory assetGroup = _assetGroupRegistry.listAssetGroup(_assetGroupId);

        uint256 usdWorth = 0;
        for (uint256 i = 0; i < assetGroup.length; i++) {
            usdWorth += priceFeedManager.assetToUsdCustomPrice(
                assetGroup[i], IERC20(assetGroup[i]).balanceOf(address(protocol)), exchangeRates[i]
            );
        }

        return usdWorth;
    }

    function _redeemFromProtocol(address[] calldata tokens, uint256 ssts, uint256[] calldata) internal override {
        if (ssts == 0) {
            return;
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 toWithdraw = IERC20(tokens[i]).balanceOf(address(protocol)) * ssts / totalSupply();

            // withdrawal fees
            protocol.withdrawTo(tokens[i], toWithdraw * withdrawalFee / 100_00, address(protocolFees));
            // withdraw
            protocol.withdraw(tokens[i], toWithdraw * (100_00 - withdrawalFee) / 100_00);
        }
    }

    function setDepositFee(uint256 newDepositFee) external {
        require(newDepositFee < 100_00);

        depositFee = newDepositFee;
    }

    function setWithdrawalFee(uint256 newWithdrawalFee) external {
        require(newWithdrawalFee < 100_00);

        withdrawalFee = newWithdrawalFee;
    }

    function setAssetRatio(uint256[] calldata newRatios) external {
        if (ratios.length != newRatios.length) {
            revert("wrong ratio length");
        }

        ratios = newRatios;
    }

    function beforeDepositCheck(uint256[] memory amounts, uint256[] calldata slippages) public view override {}

    function beforeRedeemalCheck(uint256 ssts, uint256[] calldata slippages) public view override {}

    function _emergencyWithdrawImpl(uint256[] calldata, address recipient) internal override {
        address[] memory assetGroup = assets();
        for (uint256 i; i < assetGroup.length; i++) {
            protocol.withdrawTo(assetGroup[i], IERC20(assetGroup[i]).balanceOf(address(protocol)), recipient);
        }
    }
}

contract MockProtocol {
    using SafeERC20 for IERC20;

    function test_mock() external pure {}

    function withdraw(address token, uint256 amount) external {
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    function withdrawTo(address token, uint256 amount, address to) external {
        IERC20(token).safeTransfer(to, amount);
    }
}
