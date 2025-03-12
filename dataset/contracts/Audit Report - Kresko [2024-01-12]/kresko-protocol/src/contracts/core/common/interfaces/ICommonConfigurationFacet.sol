// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import {FeedConfiguration} from "common/Types.sol";

interface ICommonConfigurationFacet {
    /**
     * @notice Updates the fee recipient.
     * @param _newFeeRecipient The new fee recipient.
     */
    function setFeeRecipient(address _newFeeRecipient) external;

    /**
     * @dev Updates the contract's minimum debt value.
     * @param _newMinDebtValue The new minimum debt value as a wad.
     */
    function setMinDebtValue(uint96 _newMinDebtValue) external;

    /**
     * @notice Sets the decimal precision of external oracle
     * @param _decimals Amount of decimals
     */
    function setDefaultOraclePrecision(uint8 _decimals) external;

    /**
     * @notice Sets the decimal precision of external oracle
     * @param _oracleDeviationPct Amount of decimals
     */
    function setMaxPriceDeviationPct(uint16 _oracleDeviationPct) external;

    /**
     * @notice Sets L2 sequencer uptime feed address
     * @param _sequencerUptimeFeed sequencer uptime feed address
     */
    function setSequencerUptimeFeed(address _sequencerUptimeFeed) external;

    /**
     * @notice Sets sequencer grace period time
     * @param _sequencerGracePeriodTime grace period time
     */
    function setSequencerGracePeriod(uint32 _sequencerGracePeriodTime) external;

    /**
     * @notice Sets the time in seconds until a price is considered stale.
     * @param _staleTime Time in seconds.
     */
    function setStaleTime(uint32 _staleTime) external;

    /**
     * @notice Set feeds for a ticker.
     * @param _ticker Ticker in bytes32 eg. bytes32("ETH")
     * @param _feedConfig List oracle configuration containing oracle identifiers and feed addresses.
     * @custom:signature setFeedsForTicker(bytes32,(uint8[2],address[2]))
     * @custom:selector 0xbe079e8e
     */
    function setFeedsForTicker(bytes32 _ticker, FeedConfiguration memory _feedConfig) external;

    /**
     * @notice Set chainlink feeds for tickers.
     * @dev Has modifiers: onlyRole.
     * @param _tickers Bytes32 list of tickers
     * @param _feeds List of feed addresses.
     */
    function setChainlinkFeeds(bytes32[] calldata _tickers, address[] calldata _feeds) external;

    /**
     * @notice Set api3 feeds for tickers.
     * @dev Has modifiers: onlyRole.
     * @param _tickers Bytes32 list of tickers
     * @param _feeds List of feed addresses.
     */
    function setApi3Feeds(bytes32[] calldata _tickers, address[] calldata _feeds) external;

    /**
     * @notice Set a vault feed for ticker.
     * @dev Has modifiers: onlyRole.
     * @param _ticker Ticker in bytes32 eg. bytes32("ETH")
     * @param _vaultAddr Vault address
     * @custom:signature setVaultFeed(bytes32,address)
     * @custom:selector 0xc3f9c901
     */
    function setVaultFeed(bytes32 _ticker, address _vaultAddr) external;

    /**
     * @notice Set ChainLink feed address for ticker.
     * @param _ticker Ticker in bytes32 eg. bytes32("ETH")
     * @param _feedAddr The feed address.
     * @custom:signature setChainLinkFeed(bytes32,address)
     * @custom:selector 0xe091f77a
     */
    function setChainLinkFeed(bytes32 _ticker, address _feedAddr) external;

    /**
     * @notice Set API3 feed address for an asset.
     * @param _ticker Ticker in bytes32 eg. bytes32("ETH")
     * @param _feedAddr The feed address.
     * @custom:signature setApi3Feed(bytes32,address)
     * @custom:selector 0x7e9f9837
     */
    function setApi3Feed(bytes32 _ticker, address _feedAddr) external;

    /**
     * @notice Sets phase of gating mechanism
     * @param _phase phase id
     */
    function setGatingPhase(uint8 _phase) external;

    /**
     * @notice Sets address of Kreskian NFT contract
     * @param _kreskian kreskian nft contract address
     */
    function setKreskianCollection(address _kreskian) external;

    /**
     * @notice Sets address of Quest For Kresk NFT contract
     * @param _questForKresk Quest For Kresk NFT contract address
     */
    function setQuestForKreskCollection(address _questForKresk) external;
}
