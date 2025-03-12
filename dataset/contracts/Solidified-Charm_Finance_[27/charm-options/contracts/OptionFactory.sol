// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./libraries/openzeppelin/ERC20UpgradeSafe.sol";
import "./libraries/CloneFactory.sol";
import "./libraries/UniERC20.sol";
import "./OptionMarket.sol";
import "./OptionSymbol.sol";

contract OptionFactory is CloneFactory, OptionSymbol, ReentrancyGuard {
    using Address for address;
    using SafeERC20 for IERC20;
    using UniERC20 for IERC20;
    using SafeMath for uint256;

    address public optionMarketLibrary;
    address public optionTokenLibrary;
    address[] public markets;

    constructor(address _optionMarketLibrary, address _optionTokenLibrary) public {
        require(_optionMarketLibrary != address(0), "optionMarketLibrary should not be address 0");
        require(_optionTokenLibrary != address(0), "optionTokenLibrary should not be address 0");
        optionMarketLibrary = _optionMarketLibrary;
        optionTokenLibrary = _optionTokenLibrary;
    }

    function createMarket(
        address baseAsset,
        address quoteAsset,
        address oracle,
        uint256[] memory strikePrices,
        uint256 expiryTime,
        bool isPut,
        uint256 tradingFee
    ) external nonReentrant returns (address marketAddress) {
        marketAddress = createClone(optionMarketLibrary);
        markets.push(marketAddress);

        string memory underlyingSymbol = IERC20(baseAsset).uniSymbol();
        string memory lpSymbol = getMarketSymbol(underlyingSymbol, expiryTime, isPut);
        address baseToken = isPut ? quoteAsset : baseAsset;

        address[] memory longTokens = new address[](strikePrices.length);
        address[] memory shortTokens = new address[](strikePrices.length);

        // use scoping to avoid stack too deep error
        {
            uint8 decimals = IERC20(baseToken).isETH() ? 18 : ERC20UpgradeSafe(baseToken).decimals();

            for (uint256 i = 0; i < strikePrices.length; i++) {
                longTokens[i] = createClone(optionTokenLibrary);
                string memory optionSymbol =
                    getOptionSymbol(underlyingSymbol, strikePrices[i], expiryTime, isPut, true);
                OptionToken(longTokens[i]).initialize(marketAddress, optionSymbol, optionSymbol, decimals);
            }

            for (uint256 i = 0; i < strikePrices.length; i++) {
                shortTokens[i] = createClone(optionTokenLibrary);
                string memory optionSymbol =
                    getOptionSymbol(underlyingSymbol, strikePrices[i], expiryTime, isPut, false);
                OptionToken(shortTokens[i]).initialize(marketAddress, optionSymbol, optionSymbol, decimals);
            }
        }

        OptionMarket(marketAddress).initialize(
            baseToken,
            oracle,
            longTokens,
            shortTokens,
            strikePrices,
            expiryTime,
            isPut,
            tradingFee,
            lpSymbol
        );

        // transfer ownership to sender
        OptionMarket(marketAddress).transferOwnership(msg.sender);
    }

    function numMarkets() external view returns (uint256) {
        return markets.length;
    }
}
