// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../interfaces/PythInterface.sol";

contract MockPyth is AbstractPyth {
    mapping(bytes32 => PythStructs.PriceFeed) priceFeeds;
    uint64 sequenceNumber;

    uint256 singleUpdateFeeInWei;
    uint256 validTimePeriod;

    constructor(uint256 _validTimePeriod, uint256 _singleUpdateFeeInWei) {
        singleUpdateFeeInWei = _singleUpdateFeeInWei;
        validTimePeriod = _validTimePeriod;
    }

    function queryPriceFeed(bytes32 id) public view override returns (PythStructs.PriceFeed memory priceFeed) {
        require(priceFeeds[id].id != 0, "no price feed found for the given price id");
        return priceFeeds[id];
    }

    // simply update price feeds
    function updatePriceFeedsHarness(PythStructs.PriceFeed[] calldata feeds) external {
        require(feeds.length > 0, "feeds length must > 0");
        for (uint256 i = 0; i < feeds.length; ++i) {
            priceFeeds[feeds[i].id] = feeds[i];
        }
    }

    function priceFeedExists(bytes32 id) public view override returns (bool) {
        return (priceFeeds[id].id != 0);
    }

    function getValidTimePeriod() public view override returns (uint256) {
        return validTimePeriod;
    }

    // Takes an array of encoded price feeds and stores them.
    // You can create this data either by calling createPriceFeedData or
    // by using web3.js or ethers abi utilities.
    function updatePriceFeeds(bytes[] calldata updateData) public payable override {
        uint256 requiredFee = getUpdateFee(updateData.length);
        require(msg.value >= requiredFee, "Insufficient paid fee amount");

        if (msg.value > requiredFee) {
            (bool success, ) = payable(msg.sender).call{ value: msg.value - requiredFee }("");
            require(success, "failed to transfer update fee");
        }

        uint256 freshPrices = 0;

        // Chain ID is id of the source chain that the price update comes from. Since it is just a mock contract
        // We set it to 1.
        uint16 chainId = 1;

        for (uint256 i = 0; i < updateData.length; i++) {
            PythStructs.PriceFeed memory priceFeed = abi.decode(updateData[i], (PythStructs.PriceFeed));

            bool fresh = false;
            uint256 lastPublishTime = priceFeeds[priceFeed.id].price.publishTime;

            if (lastPublishTime < priceFeed.price.publishTime) {
                // Price information is more recent than the existing price information.
                fresh = true;
                priceFeeds[priceFeed.id] = priceFeed;
                freshPrices += 1;
            }

            emit PriceFeedUpdate(
                priceFeed.id,
                fresh,
                chainId,
                sequenceNumber,
                priceFeed.price.publishTime,
                lastPublishTime,
                priceFeed.price.price,
                priceFeed.price.conf
            );
        }

        // In the real contract, the input of this function contains multiple batches that each contain multiple prices.
        // This event is emitted when a batch is processed. In this mock contract we consider
        // there is only one batch of prices.
        // Each batch has (chainId, sequenceNumber) as it's unique identifier. Here chainId
        // is set to 1 and an increasing sequence number is used.
        emit BatchPriceFeedUpdate(chainId, sequenceNumber, updateData.length, freshPrices);
        sequenceNumber += 1;

        // There is only 1 batch of prices
        emit UpdatePriceFeeds(msg.sender, 1, requiredFee);
    }

    function getUpdateFee(uint256 updateDataSize) public view override returns (uint256 feeAmount) {
        return singleUpdateFeeInWei * updateDataSize;
    }

    function createPriceFeedUpdateData(
        bytes32 id,
        int64 price,
        uint64 conf,
        int32 expo,
        int64 emaPrice,
        uint64 emaConf,
        uint64 publishTime
    ) public pure returns (bytes memory priceFeedData) {
        PythStructs.PriceFeed memory priceFeed;

        priceFeed.id = id;

        priceFeed.price.price = price;
        priceFeed.price.conf = conf;
        priceFeed.price.expo = expo;
        priceFeed.price.publishTime = publishTime;

        priceFeed.emaPrice.price = emaPrice;
        priceFeed.emaPrice.conf = emaConf;
        priceFeed.emaPrice.expo = expo;
        priceFeed.emaPrice.publishTime = publishTime;

        priceFeedData = abi.encode(priceFeed);
    }
}
