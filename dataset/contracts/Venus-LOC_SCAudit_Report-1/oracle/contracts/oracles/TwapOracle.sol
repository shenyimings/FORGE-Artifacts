// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../libraries/PancakeLibrary.sol";
import "../interfaces/OracleInterface.sol";
import "../interfaces/BEP20Interface.sol";
import "../interfaces/VBep20Interface.sol";

struct Observation {
    uint256 timestamp;
    uint256 acc;
}

struct TokenConfig {
    /// @notice asset address, which can't be zero address and can be used for existance check
    address asset;
    /// @notice Decimals of underlying asset
    uint256 baseUnit;
    /// @notice The address of pancake pair
    address pancakePool;
    /// @notice Whether the token is paired with WBNB
    bool isBnbBased;
    /// @notice A flag identifies whether the pancake pair is reversed
    /// e.g. XVS-WBNB is not reversed, while WBNB-XVS is.
    bool isReversedPool;
    /// @notice TWAP update period in second, which is the minimum time in seconds required to update TWAP window
    uint256 anchorPeriod;
}

contract TwapOracle is OwnableUpgradeable, TwapInterface {
    using FixedPoint for *;

    /// @notice WBNB address
    address public WBNB;

    /// @notice the base unit of WBNB and BUSD, which are the paired tokens for all assets
    uint256 public constant bnbBaseUnit = 1e18;
    uint256 public constant busdBaseUnit = 1e18;

    uint256 public constant expScale = 1e18;

    /// @notice Configs by token
    mapping(address => TokenConfig) public tokenConfigs;

    /// @notice The current price observation of TWAP. With old and current observations
    /// we can calculate the TWAP between this range
    mapping(address => Observation) public newObservations;

    /// @notice The old price observation of TWAP
    mapping(address => Observation) public oldObservations;

    /// @notice Stored price by token
    mapping(address => uint256) public prices;

    /// @notice Emit this event when TWAP window is updated
    event TwapWindowUpdated(
        address indexed asset,
        uint256 oldTimestamp,
        uint256 oldAcc,
        uint256 newTimestamp,
        uint256 newAcc
    );

    /// @notice Emit this event when TWAP price is updated
    event AnchorPriceUpdated(address indexed asset, uint256 price, uint256 oldTimestamp, uint256 newTimestamp);

    /// @notice Emit this event when new token configs are added
    event TokenConfigAdded(address indexed asset, address indexed pancakePool, uint256 indexed anchorPeriod);

    modifier notNullAddress(address someone) {
        require(someone != address(0), "can't be zero address");
        _;
    }

    function initialize(address WBNB_) public initializer {
        __Ownable_init();
        require(WBNB_ != address(0), "WBNB can't be zero address");
        WBNB = WBNB_;
    }

    /**
     * @notice Add multiple token configs at the same time
     * @param configs config array
     */
    function setTokenConfigs(TokenConfig[] memory configs) external onlyOwner {
        require(configs.length > 0, "length can't be 0");
        for (uint8 i = 0; i < configs.length; i++) {
            setTokenConfig(configs[i]);
        }
    }

    /**
     * @notice Add single token configs
     * @param config token config struct
     */
    function setTokenConfig(
        TokenConfig memory config
    ) public onlyOwner notNullAddress(config.asset) notNullAddress(config.pancakePool) {
        require(config.anchorPeriod > 0, "anchor period must be positive");
        require(config.baseUnit > 0, "base unit must be positive");
        uint256 cumulativePrice = currentCumulativePrice(config);

        // Initialize observation data
        oldObservations[config.asset].timestamp = block.timestamp;
        newObservations[config.asset].timestamp = block.timestamp;
        oldObservations[config.asset].acc = cumulativePrice;
        newObservations[config.asset].acc = cumulativePrice;
        tokenConfigs[config.asset] = config;
        emit TokenConfigAdded(config.asset, config.pancakePool, config.anchorPeriod);
    }

    /**
     * @notice Get the underlying TWAP price of input vToken
     * @param vToken vToken address
     * @return price in USD, with 18 decimals
     */
    function getUnderlyingPrice(address vToken) external view override returns (uint256) {
        address asset = VBep20Interface(vToken).underlying();
        require(tokenConfigs[asset].asset != address(0), "asset not exist");

        uint256 price = prices[asset];

        // if price is 0, it means the price hasn't been updated yet and it's meaningless, revert
        require(price > 0, "TWAP price must be positive");

        BEP20Interface underlyingToken = BEP20Interface(VBep20Interface(vToken).underlying());
        return (price * (10 ** (18 - underlyingToken.decimals())));
    }

    /**
     * @notice Fetches the current token/WBNB and token/BUSD price accumulator from pancakeswap.
     * @return cumulative price of target token regardless of pair order
     */
    function currentCumulativePrice(TokenConfig memory config) public view returns (uint256) {
        (uint256 price0, uint256 price1, ) = PancakeOracleLibrary.currentCumulativePrices(config.pancakePool);
        if (config.isReversedPool) {
            return price1;
        } else {
            return price0;
        }
    }

    function updateTwap(address vToken) public returns (uint256) {
        address asset = VBep20Interface(vToken).underlying();
        require(tokenConfigs[asset].asset != address(0), "asset not exist");
        // Update & fetch WBNB price first, so we can calculate the price of WBNB paired token
        if (asset != WBNB && tokenConfigs[asset].isBnbBased) {
            require(tokenConfigs[WBNB].asset != address(0), "WBNB not exist");
            _updateTwapInternal(tokenConfigs[WBNB]);
        }
        return _updateTwapInternal(tokenConfigs[asset]);
    }

    /**
     * @notice Fetches the current token/BUSD price from PancakeSwap, with 18 decimals of precision.
     * @return price in USD, with 18 decimals
     */
    function _updateTwapInternal(TokenConfig memory config) internal virtual returns (uint256) {
        // pokeWindowValues already handled reversed pool cases,
        // priceAverage will always be Token/BNB or Token/BUSD TWAP price.
        (uint256 nowCumulativePrice, uint256 oldCumulativePrice, uint256 oldTimestamp) = pokeWindowValues(config);

        // This should be impossible, but better safe than sorry
        require(block.timestamp > oldTimestamp, "now must come after before");
        uint256 timeElapsed = block.timestamp - oldTimestamp;

        // Calculate Pancakge TWAP
        FixedPoint.uq112x112 memory priceAverage = FixedPoint.uq112x112(
            uint224((nowCumulativePrice - oldCumulativePrice) / timeElapsed)
        );
        // TWAP price with 1e18 decimal mantissa
        uint256 priceAverageMantissa = priceAverage.decode112with18();

        // To cancel the decimals in cumulative price, we need to mulitply the average price with
        // tokenBaseUnit / (wbnbBaseUnit or busdBaseUnit, which is 1e18)
        uint256 pairedTokenBaseUnit = config.isBnbBased ? bnbBaseUnit : busdBaseUnit;
        uint256 anchorPriceMantissa = (priceAverageMantissa * config.baseUnit) / pairedTokenBaseUnit;

        // if this token is paired with BNB, convert its price to USD
        if (config.isBnbBased) {
            uint256 bnbPrice = prices[WBNB];
            require(bnbPrice != 0, "bnb price is invalid");
            anchorPriceMantissa = (anchorPriceMantissa * bnbPrice) / bnbBaseUnit;
        }

        require(anchorPriceMantissa != 0, "twap price cannot be 0");

        emit AnchorPriceUpdated(config.asset, anchorPriceMantissa, oldTimestamp, block.timestamp);

        // save anchor price, which is 1e18 decimals
        prices[config.asset] = anchorPriceMantissa;

        return anchorPriceMantissa;
    }

    /**
     * @notice Update new and old observations of lagging window if period elapsed.
     * @return cumulative price & old observation
     */
    function pokeWindowValues(TokenConfig memory config) internal returns (uint256, uint256, uint256) {
        uint256 cumulativePrice = currentCumulativePrice(config);

        Observation memory newObservation = newObservations[config.asset];

        // Update new and old observations if elapsed time is greater than or equal to anchor period
        uint256 timeElapsed = block.timestamp - newObservation.timestamp;
        if (timeElapsed >= config.anchorPeriod) {
            oldObservations[config.asset].timestamp = newObservation.timestamp;
            oldObservations[config.asset].acc = newObservation.acc;

            newObservations[config.asset].timestamp = block.timestamp;
            newObservations[config.asset].acc = cumulativePrice;
            emit TwapWindowUpdated(
                config.asset,
                newObservation.timestamp,
                block.timestamp,
                newObservation.acc,
                cumulativePrice
            );
        }
        return (cumulativePrice, oldObservations[config.asset].acc, oldObservations[config.asset].timestamp);
    }
}
