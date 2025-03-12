// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ICommonStateFacet} from "common/interfaces/ICommonStateFacet.sol";
import {Redstone} from "libs/Redstone.sol";

import {Enums} from "common/Constants.sol";
import {cs} from "common/State.sol";
import {aggregatorV3Price, API3Price, vaultPrice} from "common/funcs/Prices.sol";

contract CommonStateFacet is ICommonStateFacet {
    /// @inheritdoc ICommonStateFacet
    function getFeeRecipient() external view returns (address) {
        return cs().feeRecipient;
    }

    /// @inheritdoc ICommonStateFacet
    function getDefaultOraclePrecision() external view returns (uint8) {
        return cs().oracleDecimals;
    }

    /// @inheritdoc ICommonStateFacet
    function getMinDebtValue() external view returns (uint96) {
        return cs().minDebtValue;
    }

    /// @inheritdoc ICommonStateFacet
    function getOracleDeviationPct() external view returns (uint16) {
        return cs().maxPriceDeviationPct;
    }

    /// @inheritdoc ICommonStateFacet
    function getSequencerUptimeFeed() external view returns (address) {
        return cs().sequencerUptimeFeed;
    }

    /// @inheritdoc ICommonStateFacet
    function getSequencerGracePeriod() external view returns (uint32) {
        return cs().sequencerGracePeriodTime;
    }

    /// @inheritdoc ICommonStateFacet
    function getOracleTimeout() external view returns (uint32) {
        return cs().staleTime;
    }

    /// @inheritdoc ICommonStateFacet
    function getFeedForId(bytes32 _ticker, Enums.OracleType _oracleType) external view returns (address) {
        return cs().oracles[_ticker][_oracleType].feed;
    }

    /// @inheritdoc ICommonStateFacet
    function redstonePrice(bytes32 _ticker, address) external view returns (uint256) {
        return Redstone.getPrice(_ticker);
    }

    /// @inheritdoc ICommonStateFacet
    function getAPI3Price(address _feedAddr) external view returns (uint256) {
        return API3Price(_feedAddr, cs().staleTime);
    }

    /// @inheritdoc ICommonStateFacet
    function getVaultPrice(address _vaultAddr) external view returns (uint256) {
        return vaultPrice(_vaultAddr);
    }

    /// @inheritdoc ICommonStateFacet
    function getChainlinkPrice(address _feedAddr) external view returns (uint256) {
        return aggregatorV3Price(_feedAddr, cs().staleTime);
    }
}
