// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../OptionFactory.sol";
import "../OptionMarket.sol";
import "../OptionSymbol.sol";
import "../OptionToken.sol";
import "../libraries/UniERC20.sol";


contract OptionRegistry is OptionSymbol {
    using Address for address;
    using SafeERC20 for IERC20;
    using UniERC20 for IERC20;
    using SafeMath for uint256;

    struct OptionDetails {
        bool isLong;
        uint256 strikeIndex;
        uint256 strikePrice;
    }

    OptionFactory public immutable factory;
    uint256 public lastIndex;

    mapping(string => OptionMarket) internal markets;
    mapping(string => OptionToken) internal options;
    mapping(OptionToken => OptionDetails) internal optionDetails;

    /**
     * @param _factory {OptionFactory} instance from which markets are retrieved
     * @param _lastIndex Don't add markets with this index or smaller. This saves
     * gas when `populateMarkets()` is initially called
     */
    constructor(address _factory, uint256 _lastIndex) public {
        factory = OptionFactory(_factory);
        lastIndex = _lastIndex;
    }

    /**
     * @dev Fetch option market
     * @param underlying Address of underlying token. Equal to 0x0 for ETH
     * @param expiryTime Expiry time as timestamp
     * @param isPut True if put, false if call
     */
    function getMarket(IERC20 underlying, uint256 expiryTime, bool isPut) external view returns (OptionMarket) {
        string memory symbol = getMarketSymbol(underlying.uniSymbol(), expiryTime, isPut);
        return markets[symbol];
    }

    /**
     * @dev Fetch option token
     * @param underlying Address of underlying token. Equal to 0x0 for ETH
     * @param expiryTime Expiry time as timestamp
     * @param isPut True if put, false if call
     * @param strikePrice Strike price in USDC multiplied by 1e18
     * @param isLong True if long position, false if short position
     */
    function getOption(IERC20 underlying, uint256 expiryTime, bool isPut, uint256 strikePrice, bool isLong) external view returns (OptionToken) {
        string memory symbol = getOptionSymbol(underlying.uniSymbol(), strikePrice, expiryTime, isPut, isLong);
        return options[symbol];
    }

    /**
     * @dev Fetch option details
     * @param optionToken Option token
     */
    function getOptionDetails(OptionToken optionToken) external view returns (OptionDetails memory) {
        return optionDetails[optionToken];
    }

    /**
     * @dev Add mappings for any new markets that have been added to factory
     * since the last time this method was called
     */
    function populateMarkets() external {
        populateMarketsUntil(factory.numMarkets());
    }

    /**
     * @dev Same as {populateMarkets} but only adds markets up to a given index
     */
    function populateMarketsUntil(uint256 index) public {
        require(index > lastIndex, "OptionRegistry: No new markets to add");
        require(index <= factory.numMarkets(), "OptionRegistry: index out of bounds");

        for (uint256 i = lastIndex; i < index; i = i.add(1)) {
            OptionMarket market = OptionMarket(factory.markets(i));
            _populateMarket(market);
        }
        lastIndex = index;
    }

    function _populateMarket(OptionMarket market) internal {
        markets[market.symbol()] = market;

        uint256 numStrikes = market.numStrikes();
        for (uint256 i = 0; i < numStrikes; i = i.add(1)) {
            OptionToken longToken = market.longTokens(i);
            OptionToken shortToken = market.shortTokens(i);
            uint256 strikePrice = market.strikePrices(i);

            options[longToken.symbol()] = longToken;
            options[shortToken.symbol()] = shortToken;
            optionDetails[longToken] = OptionDetails(true, i, strikePrice);
            optionDetails[shortToken] = OptionDetails(false, i, strikePrice);
        }
    }
}
