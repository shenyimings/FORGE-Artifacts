// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {PercentageMath} from "libs/PercentageMath.sol";
import {WadRay} from "libs/WadRay.sol";
import {Errors} from "common/Errors.sol";
import {isSequencerUp} from "common/funcs/Utils.sol";
import {Percents} from "common/Constants.sol";
import {aggregatorV3Price} from "common/funcs/Prices.sol";
import {wadUSD} from "common/funcs/Math.sol";
import {VaultConfiguration, VaultAsset} from "vault/VTypes.sol";

/**
 * @title LibVault
 * @author Kresko
 * @notice Helper library for KreskoVault
 */
library VAssets {
    using WadRay for uint256;
    using PercentageMath for uint256;
    using PercentageMath for uint32;
    using VAssets for VaultAsset;
    using VAssets for uint256;

    /// @notice Gets the price of an asset from the oracle speficied.
    function price(VaultAsset storage self, VaultConfiguration storage config) internal view returns (uint256 answer) {
        if (!isSequencerUp(config.sequencerUptimeFeed, config.sequencerGracePeriodTime)) {
            revert Errors.L2_SEQUENCER_DOWN();
        }
        answer = aggregatorV3Price(address(self.feed), self.staleTime);
        if (answer == 0) revert Errors.ZERO_OR_STALE_VAULT_PRICE(Errors.id(address(self.token)), address(self.feed), answer);
    }

    /// @notice Gets the price of an asset from the oracle speficied.
    function handleDepositFee(
        VaultAsset storage self,
        uint256 assets
    ) internal view returns (uint256 assetsWithFee, uint256 fee) {
        uint256 depositFee = self.depositFee;
        if (depositFee == 0) {
            return (assets, 0);
        }

        fee = assets.percentMul(depositFee);
        assetsWithFee = assets - fee;
    }

    /// @notice Gets the price of an asset from the oracle speficied.
    function handleMintFee(VaultAsset storage self, uint256 assets) internal view returns (uint256 assetsWithFee, uint256 fee) {
        uint256 depositFee = self.depositFee;
        if (depositFee == 0) {
            return (assets, 0);
        }

        assetsWithFee = assets.percentDiv(Percents.HUNDRED - depositFee);
        fee = assetsWithFee - assets;
    }

    /// @notice Gets the price of an asset from the oracle speficied.
    function handleWithdrawFee(
        VaultAsset storage self,
        uint256 assets
    ) internal view returns (uint256 assetsWithFee, uint256 fee) {
        uint256 withdrawFee = self.withdrawFee;
        if (withdrawFee == 0) {
            return (assets, 0);
        }

        assetsWithFee = assets.percentDiv(Percents.HUNDRED - withdrawFee);
        fee = assetsWithFee - assets;
    }

    /// @notice Gets the price of an asset from the oracle speficied.
    function handleRedeemFee(
        VaultAsset storage self,
        uint256 assets
    ) internal view returns (uint256 assetsWithFee, uint256 fee) {
        uint256 withdrawFee = self.withdrawFee;
        if (withdrawFee == 0) {
            return (assets, 0);
        }

        fee = assets.percentMul(withdrawFee);
        assetsWithFee = assets - fee;
    }

    /// @notice Gets the oracle decimal precision USD value for `amount`.
    /// @param config vault configuration.
    /// @param amount amount of tokens to get USD value for.
    function usdWad(
        VaultAsset storage self,
        VaultConfiguration storage config,
        uint256 amount
    ) internal view returns (uint256) {
        // uint256 result = amount.wadMul(self.price(config)).wadDiv(10 ** config.oracleDecimals);
        // uint256 oldResult = (amount * (10 ** (18 - config.oracleDecimals)) * self.price(config)) / 10 ** self.decimals;
        return wadUSD(amount, self.decimals, self.price(config), config.oracleDecimals);
    }

    /// @notice Gets the total deposit value of `self` in USD, oracle precision.
    function getDepositValue(VaultAsset storage self, VaultConfiguration storage config) internal view returns (uint256) {
        uint256 bal = self.token.balanceOf(address(this));
        if (bal == 0) return 0;
        return bal.wadMul(self.price(config));
    }

    /// @notice Gets the total deposit value of `self` in USD, oracle precision.
    function getDepositValueWad(VaultAsset storage self, VaultConfiguration storage config) internal view returns (uint256) {
        uint256 bal = self.token.balanceOf(address(this));
        if (bal == 0) return 0;
        return self.usdWad(config, bal);
    }

    /// @notice Gets the a token amount for `value` USD, oracle precision.
    function getAmount(
        VaultAsset storage self,
        VaultConfiguration storage config,
        uint256 value
    ) internal view returns (uint256) {
        uint256 valueScaled = (value * 1e18) / 10 ** ((36 - config.oracleDecimals) - self.decimals);

        return valueScaled / self.price(config);
    }
}
