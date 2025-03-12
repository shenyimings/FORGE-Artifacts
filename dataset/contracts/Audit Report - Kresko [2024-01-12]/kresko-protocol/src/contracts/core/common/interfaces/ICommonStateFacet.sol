// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import {Enums} from "common/Constants.sol";

interface ICommonStateFacet {
    /// @notice The recipient of protocol fees.
    function getFeeRecipient() external view returns (address);

    /// @notice Offchain oracle decimals
    function getDefaultOraclePrecision() external view returns (uint8);

    /// @notice max deviation between main oracle and fallback oracle
    function getOracleDeviationPct() external view returns (uint16);

    /// @notice The minimum USD value of an individual synthetic asset debt position.
    function getMinDebtValue() external view returns (uint96);

    /// @notice Get the L2 sequencer uptime feed address.
    function getSequencerUptimeFeed() external view returns (address);

    /// @notice Get the L2 sequencer uptime feed grace period
    function getSequencerGracePeriod() external view returns (uint32);

    /// @notice Get stale timeout treshold for oracle answers.
    function getOracleTimeout() external view returns (uint32);

    /**
     * @notice Get tickers configured feed address for the oracle type.
     * @param _ticker Ticker in bytes32, eg. bytes32("ETH").
     * @param _oracleType The oracle type.
     * @return feedAddr Feed address matching the oracle type given.
     * @custom:signature getFeedForId(bytes32,address)
     * @custom:selector 0xed1d3e94
     */

    function getFeedForId(bytes32 _ticker, Enums.OracleType _oracleType) external view returns (address feedAddr);

    /**
     * @notice Price getter for AggregatorV3/Chainlink type feeds.
     * @notice Returns 0-price if answer is stale. This triggers the use of a secondary provider if available.
     * @dev Valid call will revert if the answer is negative.
     * @param _feedAddr AggregatorV3 type feed address.
     * @return uint256 Price answer from the feed, 0 if the price is stale.
     * @custom:signature getChainlinkPrice(address)
     * @custom:selector 0xbd58fe56
     */
    function getChainlinkPrice(address _feedAddr) external view returns (uint256);

    /**
     * @notice Price getter for Vault based asset.
     * @notice Reverts if for stale, 0 or negative answers.
     * @param _vaultAddr IVaultFeed type feed address.
     * @return uint256 Current price of one vault share.
     * @custom:signature getVaultPrice(address)
     * @custom:selector 0xec917bca
     */

    function getVaultPrice(address _vaultAddr) external view returns (uint256);

    /**
     * @notice Price getter for Redstone, extracting the price from "hidden" calldata.
     * Reverts for a number of reasons, notably:
     * 1. Invalid calldata
     * 2. Not enough signers for the price data.
     * 2. Wrong signers for the price data.
     * 4. Stale price data.
     * 5. Not enough data points
     * @param _ticker The reference asset ticker in bytes32, eg. bytes32("ETH").
     * @return uint256 Extracted price with enough unique signers.
     * @custom:signature redstonePrice(bytes32,address)
     * @custom:selector 0x0acb75e3
     */
    function redstonePrice(bytes32 _ticker, address) external view returns (uint256);

    /**
     * @notice Price getter for API3 type feeds.
     * @notice Decimal precision is NOT the same as other sources.
     * @notice Returns 0-price if answer is stale.This triggers the use of a secondary provider if available.
     * @dev Valid call will revert if the answer is negative.
     * @param _feedAddr IProxy type feed address.
     * @return uint256 Price answer from the feed, 0 if the price is stale.
     * @custom:signature getAPI3Price(address)
     * @custom:selector 0xe939010d
     */
    function getAPI3Price(address _feedAddr) external view returns (uint256);
}
