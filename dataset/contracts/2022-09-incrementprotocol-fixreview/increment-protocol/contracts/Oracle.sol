// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

// contracts
import {IncreAccessControl} from "./utils/IncreAccessControl.sol";

// libraries
import {LibReserve} from "./lib/LibReserve.sol";
import {LibMath} from "./lib/LibMath.sol";

// interfaces
import {IERC20Metadata} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {AggregatorV3Interface} from "../lib/chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC4626} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

/// @notice Oracle contract relying on Chainlink for price
contract Oracle is IOracle, IncreAccessControl {
    using LibMath for uint256;
    using LibMath for int256;

    // constants
    uint8 internal constant PROTOCOL_PRECISION = 18;

    // parameterization
    uint256 public override gracePeriod;
    AggregatorV3Interface public override sequencerUptimeFeed;

    // dependencies
    mapping(address => AssetOracle) public assetToOracles;

    constructor(AggregatorV3Interface _sequencerUptimeFeed, uint256 _gracePeriod) {
        setGracePeriod(_gracePeriod);
        setSequencerUptimeFeed(_sequencerUptimeFeed);
    }

    /* ****************** */
    /*     Governance     */
    /* ****************** */

    /// @notice Add or update an oracle address
    /// @param asset Address of the asset to add an oracle for
    /// @param aggregator Address of the Chainlink oracle
    /// @param heartBeat Minimum update frequency (in seconds)
    /// @param isVault Whether the asset provided is a ERC-4626 vault
    function setOracle(address asset, AggregatorV3Interface aggregator, uint24 heartBeat, bool isVault)
        external
        override
        onlyRole(GOVERNANCE)
    {
        if (address(asset) == address(0)) revert Oracle_AssetZeroAddress();
        if (address(aggregator) == address(0)) revert Oracle_AggregatorZeroAddress();
        AssetOracle storage assetOracle = assetToOracles[asset];

        if (isVault) {
            assetOracle.isVaultAsset = true;

            asset = IERC4626(asset).asset();
        }

        assetOracle.heartBeat = heartBeat;
        assetOracle.aggregator = aggregator;
        emit OracleUpdated(asset, aggregator, isVault);
    }

    /// @notice Set a fixed prices for assets which do not require a price feed (i.e. UA)
    /// @dev The decimals price must be 18 even if the original price feed is different,
    ///      e.g. USDC/USD chainlink oracle decimals is 8 but if we set it a fixed price it must be 18 decimals.
    /// @param asset Address of asset to set a fixed price for
    /// @param fixedPrice Price to choose as the fixed price. 18 decimals
    function setFixedPrice(address asset, int256 fixedPrice) external override onlyRole(GOVERNANCE) {
        if (address(assetToOracles[asset].aggregator) == address(0)) revert Oracle_UnsupportedAsset();

        assetToOracles[asset].fixedPrice = fixedPrice;
        emit AssetGotFixedPrice(asset, fixedPrice);
    }

    /// @notice Update the heartBeat parameter of an oracle. To be used only if Chainlink updates this parameter
    /// @param asset Address of asset to update the heartBeat from
    /// @param newHeartBeat Value of the new heartBeat. In seconds
    function setHeartBeat(address asset, uint24 newHeartBeat) external override onlyRole(GOVERNANCE) {
        if (address(assetToOracles[asset].aggregator) == address(0)) revert Oracle_UnsupportedAsset();
        if (newHeartBeat == 0) revert Oracle_IncorrectHeartBeat();

        assetToOracles[asset].heartBeat = newHeartBeat;
        emit HeartBeatUpdated(asset, newHeartBeat);
    }

    /// @notice Set sequencer uptime feed, i.e. an oracle like contract telling whether the L2 sequencer is up or not
    /// @param newSequencerUptimeFeed Address of the sequencerUptimeFeed contract
    function setSequencerUptimeFeed(AggregatorV3Interface newSequencerUptimeFeed)
        public
        override
        onlyRole(GOVERNANCE)
    {
        if (address(newSequencerUptimeFeed) == address(0)) revert Oracle_SequencerUptimeFeedZeroAddress();

        sequencerUptimeFeed = newSequencerUptimeFeed;
        emit SequencerUptimeFeedUpdated(newSequencerUptimeFeed);
    }

    /// @notice Set grace period, i.e. a period that must be elapsed after the sequencer is back to fetch new price
    /// @param newGracePeriod Value of the new grace period. In seconds
    function setGracePeriod(uint256 newGracePeriod) public override onlyRole(GOVERNANCE) {
        if (newGracePeriod < 60) revert Oracle_IncorrectGracePeriod();
        if (newGracePeriod > 3600) revert Oracle_IncorrectGracePeriod();

        gracePeriod = newGracePeriod;
        emit GracePeriodUpdated(newGracePeriod);
    }

    /* ****************** */
    /*   Global getter    */
    /* ****************** */

    /// @notice Get latest Chainlink price, except if a fixed price is defined for this asset
    /// @dev Use this getter for assets which are ERC-4626 vaults
    /// @dev Pass the balance to account for slippage in the ERC4626 contract
    /// @param asset Address of asset to fetch price for
    /// @param balance Balance is only being used by `getPrice` if `asset` is a ERC-4626 token. 1e18
    function getPrice(address asset, int256 balance) external view override returns (int256 price) {
        if (address(assetToOracles[asset].aggregator) == address(0)) revert Oracle_UnsupportedAsset();

        // Check if L2 sequencer up when transaction was received
        {
            (, int256 sequencerStatus, uint256 sequencerStatusLastUpdatedAt,,) = sequencerUptimeFeed.latestRoundData();

            // 0 means sequencer is up & 1 sequencer is down
            bool isSequencerUp = sequencerStatus == 0;
            if (!isSequencerUp) revert Oracle_SequencerDown();

            // make sure the grace period has passed after the sequencer is back up
            uint256 timeSinceUp = block.timestamp - sequencerStatusLastUpdatedAt;

            if (timeSinceUp <= gracePeriod) revert Oracle_GracePeriodNotOver();
        }

        AssetOracle storage assetOracle = assetToOracles[asset];
        uint256 assetBalanceWeiPerUnit = 1e18;
        address underlyingAsset = asset;

        if (assetOracle.isVaultAsset) {
            underlyingAsset = IERC4626(asset).asset();

            // get vault balance in token precisions
            uint256 colBalance = LibReserve.wadToToken(IERC20Metadata(asset).decimals(), balance.abs().toUint256()); // erc4626 decimals

            // get underlying balance in wei precision
            uint256 assetBalance = IERC4626(asset).convertToAssets(colBalance); // asset decimals
            uint256 assetBalanceWei = LibReserve.tokenToWad(IERC20Metadata(underlyingAsset).decimals(), assetBalance); // 1e18 decimals
            assetBalanceWeiPerUnit = assetBalanceWei.wadDiv(balance.abs().toUint256());
        }

        int256 pricePerUnit = assetOracle.fixedPrice != 0
            ? assetOracle.fixedPrice
            : _getChainlinkPrice(assetOracle.aggregator, assetOracle.heartBeat);

        price = pricePerUnit.wadMul(assetBalanceWeiPerUnit.toInt256());
    }

    /* ******************** */
    /*   Internal getter    */
    /* ******************** */

    /// @notice Get latest chainlink price
    function _getChainlinkPrice(AggregatorV3Interface aggregator, uint24 heartBeat) internal view returns (int256) {
        (, int256 roundPrice,, uint256 roundTimestamp,) = aggregator.latestRoundData();

        // If the round is not complete yet, timestamp is 0
        if (roundTimestamp <= 0) revert Oracle_InvalidRoundTimestamp();
        if (roundPrice <= 0) revert Oracle_InvalidRoundPrice();

        if (roundTimestamp + uint256(heartBeat) < block.timestamp) revert Oracle_DataNotFresh();

        return _scalePrice(roundPrice, aggregator.decimals());
    }

    /// @notice Scale price up or down depending on the precision of the asset
    function _scalePrice(int256 price, uint8 assetPrecision) internal pure returns (int256) {
        if (assetPrecision < PROTOCOL_PRECISION) {
            return price * int256(10 ** uint256(PROTOCOL_PRECISION - assetPrecision));
        } else if (assetPrecision == PROTOCOL_PRECISION) {
            return price;
        }

        return price / int256(10 ** uint256(assetPrecision - PROTOCOL_PRECISION));
    }
}
