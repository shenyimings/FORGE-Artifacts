// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "../../libraries/OrderStructs.sol";

// Interfaces
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// Shared errors
import {BidTooLow, OrderInvalid, WrongCurrency, WrongFunctionSelector} from "../../interfaces/SharedErrors.sol";

// Base strategy contracts
import {BaseStrategy} from "../BaseStrategy.sol";
import {BaseStrategyChainlinkPriceLatency} from "./BaseStrategyChainlinkPriceLatency.sol";

/**
 * @title StrategyUSDDynamicAsk
 * @notice This contract allows a seller to sell an NFT priced in USD and the receivable amount to be in ETH.
 * @author LooksRare protocol team (ðŸ‘€,ðŸ’Ž)
 */
contract StrategyUSDDynamicAsk is BaseStrategy, BaseStrategyChainlinkPriceLatency {
    /**
     * @notice Wrapped ether (WETH) address.
     */
    address public immutable WETH;

    /**
     * @notice ETH/USD Chainlink price feed
     */
    AggregatorV3Interface public immutable priceFeed;

    /**
     * @notice Constructor
     * @param _weth Wrapped ether address
     * @param _owner Owner address
     * @param _priceFeed Address of the ETH/USD price feed
     */
    constructor(address _owner, address _weth, address _priceFeed) BaseStrategyChainlinkPriceLatency(_owner) {
        WETH = _weth;
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    /**
     * @notice This function validates the order under the context of the chosen strategy and return the fulfillable items/amounts/price/nonce invalidation status.
     *         This strategy looks at the seller's desired sale price in USD and minimum sale price in ETH, converts the USD value into ETH using Chainlink's price feed and chooses the higher price.
     * @param takerBid Taker bid struct (contains the taker bid-specific parameters for the execution of the transaction)
     * @param makerAsk Maker ask struct (contains the maker ask-specific parameters for the execution of the transaction)
     * @dev The client has to provide the seller's desired sale price in USD as the additionalParameters
     */
    function executeStrategyWithTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk
    )
        external
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated)
    {
        uint256 itemIdsLength = makerAsk.itemIds.length;

        if (itemIdsLength == 0 || itemIdsLength != makerAsk.amounts.length) {
            revert OrderInvalid();
        }

        for (uint256 i; i < itemIdsLength; ) {
            if (makerAsk.itemIds[i] != takerBid.itemIds[i] || makerAsk.amounts[i] != takerBid.amounts[i]) {
                revert OrderInvalid();
            }

            uint256 amount = makerAsk.amounts[i];

            if (amount != 1) {
                if (amount == 0) {
                    revert OrderInvalid();
                }
                if (makerAsk.assetType == 0) {
                    revert OrderInvalid();
                }
            }

            unchecked {
                ++i;
            }
        }

        if (makerAsk.currency != address(0)) {
            if (makerAsk.currency != WETH) {
                revert WrongCurrency();
            }
        }

        (, int256 answer, , uint256 updatedAt, ) = priceFeed.latestRoundData();

        if (answer <= 0) {
            revert InvalidChainlinkPrice();
        }

        if (block.timestamp - updatedAt > maxLatency) {
            revert PriceNotRecentEnough();
        }

        // The client has to provide a USD value that is augmented by 1e18.
        uint256 desiredSalePriceInUSD = abi.decode(makerAsk.additionalParameters, (uint256));

        uint256 ethPriceInUSD = uint256(answer);
        uint256 minPriceInETH = makerAsk.minPrice;
        uint256 desiredSalePriceInETH = (desiredSalePriceInUSD * 1e8) / ethPriceInUSD;

        if (minPriceInETH >= desiredSalePriceInETH) {
            price = minPriceInETH;
        } else {
            price = desiredSalePriceInETH;
        }

        if (takerBid.maxPrice < price) {
            revert BidTooLow();
        }

        itemIds = makerAsk.itemIds;
        amounts = makerAsk.amounts;
        isNonceInvalidated = true;
    }

    /**
     * @notice This function validates *only the maker* order under the context of the chosen strategy.
     *         It does not revert if the maker order is invalid. Instead it returns false and the error's 4 bytes selector.
     * @param makerAsk Maker ask struct (contains the maker ask-specific parameters for the execution of the transaction)
     * @param functionSelector Function selector for the strategy
     * @return isValid Whether the maker struct is valid
     * @return errorSelector If isValid is false, it return the error's 4 bytes selector
     */
    function isMakerAskValid(
        OrderStructs.MakerAsk calldata makerAsk,
        bytes4 functionSelector
    ) external view returns (bool isValid, bytes4 errorSelector) {
        if (functionSelector != StrategyUSDDynamicAsk.executeStrategyWithTakerBid.selector) {
            return (isValid, WrongFunctionSelector.selector);
        }

        uint256 itemIdsLength = makerAsk.itemIds.length;

        if (itemIdsLength == 0 || itemIdsLength != makerAsk.amounts.length) {
            return (isValid, OrderInvalid.selector);
        }

        for (uint256 i; i < itemIdsLength; ) {
            uint256 amount = makerAsk.amounts[i];

            if (amount != 1) {
                if (amount == 0) {
                    return (isValid, OrderInvalid.selector);
                }
                if (makerAsk.assetType == 0) {
                    return (isValid, OrderInvalid.selector);
                }
            }

            unchecked {
                ++i;
            }
        }

        if (makerAsk.currency != address(0)) {
            if (makerAsk.currency != WETH) {
                return (isValid, WrongCurrency.selector);
            }
        }

        (, int256 answer, , uint256 updatedAt, ) = priceFeed.latestRoundData();

        if (answer <= 0) {
            return (isValid, InvalidChainlinkPrice.selector);
        }

        if (block.timestamp - updatedAt > maxLatency) {
            return (isValid, PriceNotRecentEnough.selector);
        }

        isValid = true;
    }
}
