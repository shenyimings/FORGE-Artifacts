// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/access/Ownable.sol';
import './interfaces/IOpenSkyCollateralPriceOracle.sol';
import './interfaces/IOpenSkySettings.sol';
import './libraries/helpers/Errors.sol';

/**
 * @title OpenSkyCollateralPriceOracle contract
 * @author OpenSky Labs
 * @dev Implements logics of the collateral price oralce for the Aave protocol
 **/
contract OpenSkyCollateralPriceOracle is Ownable, IOpenSkyCollateralPriceOracle {
    IOpenSkySettings public immutable SETTINGS;

    mapping(address => NFTPriceData[]) public nftPriceFeedMap;
    mapping(address => mapping(uint256 => uint256)) private _prices;

    uint256 internal _roundInterval = 100;

    struct NFTPriceData {
        uint256 roundId;
        uint256 price;
        uint256 timestamp;
        uint256 cumulativePrice;
    }

    constructor(IOpenSkySettings settings) Ownable() {
        SETTINGS = settings;
    }

    /// @inheritdoc IOpenSkyCollateralPriceOracle
    function updatePrice(
        address nftAddress,
        uint256 price,
        uint256 timestamp
    ) public override onlyOwner {
        NFTPriceData[] storage prices = nftPriceFeedMap[nftAddress];
        NFTPriceData memory latestPriceData = prices.length > 0
            ? prices[prices.length - 1]
            : NFTPriceData({roundId: 0, price: 0, timestamp: 0, cumulativePrice: 0});
        require(timestamp > latestPriceData.timestamp, Errors.PRICE_ORACLE_INCORRECT_TIMESTAMP);
        uint256 cumulativePrice = latestPriceData.cumulativePrice +
            (timestamp - latestPriceData.timestamp) *
            latestPriceData.price;
        uint256 roundId = latestPriceData.roundId + 1;
        NFTPriceData memory data = NFTPriceData({
            price: price,
            timestamp: timestamp,
            roundId: roundId,
            cumulativePrice: cumulativePrice
        });
        prices.push(data);

        emit UpdatePrice(nftAddress, price, timestamp, roundId);
    }

    /**
     * @notice Updates floor prices of NFT collections
     * @param nftAddresses Addresses of NFT collections
     * @param prices Floor prices of NFT collections
     * @param timestamp The timestamp when prices happened
     **/
    function updatePrices(
        address[] memory nftAddresses,
        uint256[] memory prices,
        uint256 timestamp
    ) external onlyOwner {
        require(nftAddresses.length == prices.length, Errors.PRICE_ORACLE_PARAMS_ERROR);
        for (uint256 i = 0; i < nftAddresses.length; i++) {
            updatePrice(nftAddresses[i], prices[i], timestamp);
        }
    }
    
    /**
     * @notice Updates round interval that is used for calculating TWAP price
     * @param roundInterval The round interval will be set
     **/
    function updateRoundInterval(uint256 roundInterval) external onlyOwner {
        _roundInterval = roundInterval;
    }

    /// @inheritdoc IOpenSkyCollateralPriceOracle
    function getPrice(
        uint256 reserveId,
        address nftAddress,
        uint256 tokenId
    ) external view override returns (uint256) {
        return getTwapPrice(nftAddress, _roundInterval);
    }

    /**
     * @notice Returns the TWAP price of NFT during the particular interval
     * @param nftAddress The address of the NFT
     * @param roundInterval The round interval
     * @return The price of the NFT
     **/
    function getTwapPrice(address nftAddress, uint256 roundInterval) public view returns (uint256) {
        require(roundInterval != 0, Errors.PRICE_ORACLE_ROUND_INTERVAL_CAN_NOT_BE_0);

        uint256 priceFeedLength = getPriceFeedLength(nftAddress);
        require(priceFeedLength > 0, Errors.PRICE_ORACLE_HAS_NO_PRICE_FEED);
        uint256 currentRound = priceFeedLength - 1;
        NFTPriceData memory currentPriceData = nftPriceFeedMap[nftAddress][currentRound];
        if (priceFeedLength == 1) {
            return currentPriceData.price;
        }
        uint256 previousRound = currentRound > roundInterval ? currentRound - roundInterval : 0;
        NFTPriceData memory previousPriceData = nftPriceFeedMap[nftAddress][previousRound];
        return
            (currentPriceData.cumulativePrice - previousPriceData.cumulativePrice) /
            (currentPriceData.timestamp - previousPriceData.timestamp);
    }

    /**
     * @notice Returns the data of the particular price feed
     * @param nftAddress The address of the NFT
     * @param index The index of the feed
     * @return The data of the price feed
     **/
    function getPriceData(address nftAddress, uint256 index) public view returns (NFTPriceData memory) {
        return nftPriceFeedMap[nftAddress][index];
    }

    /**
     * @notice Returns the count of price feeds about the particular NFT
     * @param nftAddress The address of the NFT
     * @return length The count of price feeds
     **/
    function getPriceFeedLength(address nftAddress) public view returns (uint256 length) {
        return nftPriceFeedMap[nftAddress].length;
    }

    /**
     * @notice Returns the latest round id of the particular NFT
     * @param nftAddress The address of the NFT
     * @return The latest round id
     **/
    function getLatestRoundId(address nftAddress) public view returns (uint256) {
        uint256 len = getPriceFeedLength(nftAddress);
        if (len == 0) {
            return 0;
        }
        return nftPriceFeedMap[nftAddress][len - 1].roundId;
    }

    /**
     * @notice Check if the address of NFT is on the whitelist 
     * @param nftAddress The address of the NFT
     * @return true if the address of NFT is on the whitelist
     **/
    function _isOnWhitelist(address nftAddress) internal view returns (bool) {
        // check it is on whitelist
        if (SETTINGS.isWhitelistOn()) {
            return SETTINGS.inWhitelist(nftAddress);
        }
        return true;
    }

}
