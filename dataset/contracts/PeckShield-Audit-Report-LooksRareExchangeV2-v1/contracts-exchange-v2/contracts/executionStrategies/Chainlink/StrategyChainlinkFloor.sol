// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Chainlink aggregator interface
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// Libraries
import {OrderStructs} from "../../libraries/OrderStructs.sol";
import {CurrencyValidator} from "../../libraries/CurrencyValidator.sol";

// Errors
import {AskTooHigh, BidTooLow, OrderInvalid, CurrencyInvalid, FunctionSelectorInvalid, QuoteTypeInvalid} from "../../errors/SharedErrors.sol";
import {DiscountGreaterThanFloorPrice, ChainlinkPriceInvalid, PriceFeedNotAvailable, PriceNotRecentEnough} from "../../errors/ChainlinkErrors.sol";

// Enums
import {QuoteType} from "../../enums/QuoteType.sol";

// Base strategy contracts
import {BaseStrategy, IStrategy} from "../BaseStrategy.sol";
import {BaseStrategyChainlinkMultiplePriceFeeds} from "./BaseStrategyChainlinkMultiplePriceFeeds.sol";

// Constants
import {ONE_HUNDRED_PERCENT_IN_BP} from "../../constants/NumericConstants.sol";

/**
 * @title StrategyChainlinkFloor
 * @notice These strategies allow a seller to make a floor price + premium ask
 *         and a buyer to make a floor price - discount collection bid.
 *         Currently Chainlink only has price feeds for ERC721 tokens, but these
 *         strategies can also support ERC1155 tokens as long as the trade amount
 *         is 1.
 * @author LooksRare protocol team (ðŸ‘€,ðŸ’Ž)
 */
contract StrategyChainlinkFloor is BaseStrategy, BaseStrategyChainlinkMultiplePriceFeeds {
    /**
     * @notice Wrapped ether (WETH) address.
     */
    address public immutable WETH;

    /**
     * @notice Constructor
     * @param _owner Owner address
     * @param _weth Address of WETH
     */
    constructor(address _owner, address _weth) BaseStrategyChainlinkMultiplePriceFeeds(_owner) {
        WETH = _weth;
    }

    /**
     * @notice This function validates the order under the context of the chosen strategy
     *         and returns the fulfillable items/amounts/price/nonce invalidation status
     *         This strategy looks at the seller's desired execution price in ETH (floor + premium)
     *         and minimum execution price and chooses the higher price.
     * @param takerBid Taker bid struct (taker bid-specific parameters for the execution)
     * @param makerAsk Maker ask struct (maker ask-specific parameters for the execution)
     * @return price The final execution price
     * @return itemIds The final item ids to be traded
     * @return amounts The corresponding amounts for each item id. It should always be 1 for any collection type.
     * @return isNonceInvalidated Whether the order's nonce will be invalidated after executing the order
     * @dev The client has to provide the bidder's desired premium amount in ETH
     *      from the floor price as the additionalParameters.
     */
    function executeFixedPremiumStrategyWithTakerBid(
        OrderStructs.Taker calldata takerBid,
        OrderStructs.Maker calldata makerAsk
    )
        external
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated)
    {
        return _executePremiumStrategyWithTakerBid(takerBid, makerAsk, _calculateFixedPremium);
    }

    /**
     * @notice This function validates the order under the context of the chosen strategy
     *         and returns the fulfillable items/amounts/price/nonce invalidation status.
     *         This strategy looks at the seller's desired execution price in ETH (floor * (1 + premium))
     *         and minimum execution price and chooses the higher price.
     * @param takerBid Taker bid struct (taker bid-specific parameters for the execution)
     * @param makerAsk Maker ask struct (maker ask-specific parameters for the execution)
     * @return price The final execution price
     * @return itemIds The final item ids to be traded
     * @return amounts The corresponding amounts for each item id. It should always be 1 for any collection type.
     * @return isNonceInvalidated Whether the order's nonce will be invalidated after executing the order
     * @dev The client has to provide the bidder's desired premium basis points
     *      from the floor price as the additionalParameters.
     */
    function executeBasisPointsPremiumStrategyWithTakerBid(
        OrderStructs.Taker calldata takerBid,
        OrderStructs.Maker calldata makerAsk
    )
        external
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated)
    {
        return _executePremiumStrategyWithTakerBid(takerBid, makerAsk, _calculateBasisPointsPremium);
    }

    /**
     * @notice This function validates the order under the context of the chosen strategy
     *         and returns the fulfillable items/amounts/price/nonce invalidation status.
     *         This strategy looks at the bidder's desired execution price in ETH (floor - discount)
     *         and maximum execution price and chooses the lower price.
     * @param takerAsk Taker ask struct (taker ask-specific parameters for the execution)
     * @param makerBid Maker bid struct (maker bid-specific parameters for the execution)
     * @return price The final execution price
     * @return itemIds The final item ids to be traded
     * @return amounts The corresponding amounts for each item id. It should always be 1 for any collection type.
     * @return isNonceInvalidated Whether the order's nonce will be invalidated after executing the order
     * @dev The client has to provide the bidder's desired discount amount in ETH
     *      from the floor price as the additionalParameters.
     */
    function executeFixedDiscountCollectionOfferStrategyWithTakerAsk(
        OrderStructs.Taker calldata takerAsk,
        OrderStructs.Maker calldata makerBid
    )
        external
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated)
    {
        return _executeDiscountCollectionOfferStrategyWithTakerAsk(takerAsk, makerBid, _calculateFixedDiscount);
    }

    /**
     * @notice This function validates the order under the context of the chosen strategy
     *         and returns the fulfillable items/amounts/price/nonce invalidation status.
     *         This strategy looks at the bidder's desired execution price in ETH (floor * (1 - discount))
     *         and maximum execution price and chooses the lower price.
     * @param takerAsk Taker ask struct (taker ask-specific parameters for the execution)
     * @param makerBid Maker bid struct (maker bid-specific parameters for the execution)
     * @return price The final execution price
     * @return itemIds The final item ids to be traded
     * @return amounts The corresponding amounts for each item id. It should always be 1 for any collection type.
     * @return isNonceInvalidated Whether the order's nonce will be invalidated after executing the order
     * @dev The client has to provide the bidder's desired discount basis points
     *      from the floor price as the additionalParameters.
     */
    function executeBasisPointsDiscountCollectionOfferStrategyWithTakerAsk(
        OrderStructs.Taker calldata takerAsk,
        OrderStructs.Maker calldata makerBid
    )
        external
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated)
    {
        return _executeDiscountCollectionOfferStrategyWithTakerAsk(takerAsk, makerBid, _calculateBasisPointsDiscount);
    }

    /**
     * @inheritdoc IStrategy
     */
    function isMakerOrderValid(
        OrderStructs.Maker calldata makerOrder,
        bytes4 functionSelector
    ) external view override returns (bool isValid, bytes4 errorSelector) {
        if (
            functionSelector == StrategyChainlinkFloor.executeBasisPointsPremiumStrategyWithTakerBid.selector ||
            functionSelector == StrategyChainlinkFloor.executeFixedPremiumStrategyWithTakerBid.selector
        ) {
            (isValid, errorSelector) = _isMakerAskValid(makerOrder);
        } else if (
            functionSelector ==
            StrategyChainlinkFloor.executeBasisPointsDiscountCollectionOfferStrategyWithTakerAsk.selector ||
            functionSelector == StrategyChainlinkFloor.executeFixedDiscountCollectionOfferStrategyWithTakerAsk.selector
        ) {
            (isValid, errorSelector) = _isMakerBidValid(makerOrder, functionSelector);
        } else {
            return (isValid, FunctionSelectorInvalid.selector);
        }
    }

    /**
     * @param _calculateDesiredPrice _calculateFixedPremium or _calculateBasisPointsPremium
     */
    function _executePremiumStrategyWithTakerBid(
        OrderStructs.Taker calldata takerBid,
        OrderStructs.Maker calldata makerAsk,
        function(uint256 /* floorPrice */, uint256 /* premium */)
            internal
            pure
            returns (uint256 /* desiredPrice */) _calculateDesiredPrice
    )
        private
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated)
    {
        CurrencyValidator.allowNativeOrAllowedCurrency(makerAsk.currency, WETH);

        if (makerAsk.itemIds.length != 1 || makerAsk.amounts.length != 1) {
            revert OrderInvalid();
        }

        uint256 floorPrice = _getFloorPrice(makerAsk.collection);
        uint256 premium = abi.decode(makerAsk.additionalParameters, (uint256));
        uint256 desiredPrice = _calculateDesiredPrice(floorPrice, premium);

        if (desiredPrice >= makerAsk.price) {
            price = desiredPrice;
        } else {
            price = makerAsk.price;
        }

        uint256 maxPrice = abi.decode(takerBid.additionalParameters, (uint256));
        if (maxPrice < price) {
            revert BidTooLow();
        }

        itemIds = makerAsk.itemIds;
        amounts = makerAsk.amounts;
        isNonceInvalidated = true;
    }

    /**
     * @dev There is no fixed premium verification. We will let the runtime reverts
     *      the transaction if there is an overflow.
     */
    function _calculateFixedPremium(uint256 floorPrice, uint256 premium) internal pure returns (uint256 desiredPrice) {
        desiredPrice = floorPrice + premium;
    }

    /**
     * @dev There is no basis points premium verification. We will let the runtime reverts
     *      the transaction if there is an overflow.
     */
    function _calculateBasisPointsPremium(
        uint256 floorPrice,
        uint256 premium
    ) internal pure returns (uint256 desiredPrice) {
        desiredPrice = (floorPrice * (ONE_HUNDRED_PERCENT_IN_BP + premium)) / ONE_HUNDRED_PERCENT_IN_BP;
    }

    /**
     * @param _calculateDesiredPrice _calculateFixedDiscount or _calculateBasisPointsDiscount
     */
    function _executeDiscountCollectionOfferStrategyWithTakerAsk(
        OrderStructs.Taker calldata takerAsk,
        OrderStructs.Maker calldata makerBid,
        function(uint256 /* floorPrice */, uint256 /* discount */)
            internal
            pure
            returns (uint256 /* desiredPrice */) _calculateDesiredPrice
    )
        private
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated)
    {
        if (makerBid.currency != WETH) {
            revert CurrencyInvalid();
        }

        if (makerBid.amounts.length != 1) {
            revert OrderInvalid();
        }

        uint256 floorPrice = _getFloorPrice(makerBid.collection);
        uint256 discount = abi.decode(makerBid.additionalParameters, (uint256));

        uint256 desiredPrice = _calculateDesiredPrice(floorPrice, discount);

        if (desiredPrice >= makerBid.price) {
            price = makerBid.price;
        } else {
            price = desiredPrice;
        }

        (uint256 offeredItemId, uint256 minPrice) = abi.decode(takerAsk.additionalParameters, (uint256, uint256));
        if (minPrice > price) {
            revert AskTooHigh();
        }

        itemIds = new uint256[](1);
        itemIds[0] = offeredItemId;
        amounts = makerBid.amounts;
        isNonceInvalidated = true;
    }

    /**
     * @dev There is a fixed discount verification, unlike the premium calculation.
     *      This is not to catch an underflow, but to demonstrate the fact that
     *      there is a limit to the discount while the only limit to the premium
     *      is the size of uint256.
     */
    function _calculateFixedDiscount(
        uint256 floorPrice,
        uint256 discount
    ) internal pure returns (uint256 desiredPrice) {
        if (floorPrice < discount) {
            revert DiscountGreaterThanFloorPrice();
        }
        unchecked {
            desiredPrice = floorPrice - discount;
        }
    }

    /**
     * @dev There is a basis points discount verification (max 99%), unlike the premium calculation.
     *      This is not to catch an underflow, but to demonstrate the fact that
     *      there is a limit to the discount while the only limit to the premium
     *      is the size of uint256.
     */
    function _calculateBasisPointsDiscount(
        uint256 floorPrice,
        uint256 discount
    ) internal pure returns (uint256 desiredPrice) {
        if (discount > ONE_HUNDRED_PERCENT_IN_BP) {
            revert OrderInvalid();
        }
        desiredPrice = (floorPrice * (ONE_HUNDRED_PERCENT_IN_BP - discount)) / ONE_HUNDRED_PERCENT_IN_BP;
    }

    function _getFloorPrice(address collection) private view returns (uint256 price) {
        address priceFeed = priceFeeds[collection];

        if (priceFeed == address(0)) {
            revert PriceFeedNotAvailable();
        }

        (, int256 answer, , uint256 updatedAt, ) = AggregatorV3Interface(priceFeed).latestRoundData();

        // Verify the answer is not null or negative
        if (answer <= 0) {
            revert ChainlinkPriceInvalid();
        }

        // Verify the latency
        if (block.timestamp - updatedAt > maxLatency) {
            revert PriceNotRecentEnough();
        }

        price = uint256(answer);
    }

    function _getFloorPriceNoRevert(
        address collection
    ) private view returns (uint256 floorPrice, bytes4 errorSelector) {
        address priceFeed = priceFeeds[collection];
        if (priceFeed == address(0)) {
            return (floorPrice, PriceFeedNotAvailable.selector);
        }

        (, int256 answer, , uint256 updatedAt, ) = AggregatorV3Interface(priceFeed).latestRoundData();
        if (answer <= 0) {
            return (floorPrice, ChainlinkPriceInvalid.selector);
        }
        if (block.timestamp - updatedAt > maxLatency) {
            return (floorPrice, PriceNotRecentEnough.selector);
        }

        return (uint256(answer), bytes4(0));
    }

    function _isMakerAskValid(
        OrderStructs.Maker calldata makerOrder
    ) private view returns (bool isValid, bytes4 errorSelector) {
        if (makerOrder.quoteType != QuoteType.Ask) {
            return (isValid, QuoteTypeInvalid.selector);
        }

        if (makerOrder.currency != address(0)) {
            if (makerOrder.currency != WETH) {
                return (isValid, CurrencyInvalid.selector);
            }
        }

        if (makerOrder.additionalParameters.length != 32) {
            return (isValid, OrderInvalid.selector);
        }

        if (makerOrder.itemIds.length != 1 || makerOrder.amounts.length != 1 || makerOrder.amounts[0] != 1) {
            return (isValid, OrderInvalid.selector);
        }

        (, bytes4 priceFeedErrorSelector) = _getFloorPriceNoRevert(makerOrder.collection);

        if (priceFeedErrorSelector == bytes4(0)) {
            isValid = true;
        } else {
            errorSelector = priceFeedErrorSelector;
        }
    }

    function _isMakerBidValid(
        OrderStructs.Maker calldata makerOrder,
        bytes4 functionSelector
    ) private view returns (bool isValid, bytes4 errorSelector) {
        if (makerOrder.quoteType != QuoteType.Bid) {
            return (isValid, QuoteTypeInvalid.selector);
        }

        if (makerOrder.currency != WETH) {
            return (isValid, CurrencyInvalid.selector);
        }

        if (makerOrder.amounts.length != 1 || makerOrder.amounts[0] != 1) {
            return (isValid, OrderInvalid.selector);
        }

        (uint256 floorPrice, bytes4 priceFeedErrorSelector) = _getFloorPriceNoRevert(makerOrder.collection);

        if (priceFeedErrorSelector != bytes4(0)) {
            return (isValid, priceFeedErrorSelector);
        }

        uint256 discount = abi.decode(makerOrder.additionalParameters, (uint256));

        if (
            functionSelector ==
            StrategyChainlinkFloor.executeBasisPointsDiscountCollectionOfferStrategyWithTakerAsk.selector
        ) {
            if (discount > ONE_HUNDRED_PERCENT_IN_BP) {
                return (isValid, OrderInvalid.selector);
            }
        }

        if (
            functionSelector == StrategyChainlinkFloor.executeFixedDiscountCollectionOfferStrategyWithTakerAsk.selector
        ) {
            if (floorPrice < discount) {
                // A special selector is returned to differentiate with OrderInvalid
                // since the maker can potentially become valid again
                return (isValid, DiscountGreaterThanFloorPrice.selector);
            }
        }

        isValid = true;
    }
}
