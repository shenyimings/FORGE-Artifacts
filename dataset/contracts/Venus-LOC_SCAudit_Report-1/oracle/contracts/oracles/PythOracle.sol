// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/PythInterface.sol";
import "../interfaces/OracleInterface.sol";
import "../interfaces/BEP20Interface.sol";
import "../interfaces/VBep20Interface.sol";

struct TokenConfig {
    bytes32 pythId;
    address asset;
    uint64 maxStalePeriod;
}

/**
 * PythOracle contract reads prices from actual Pyth oracle contract which accepts/verifies and stores the
 * updated prices from external sources
 */
contract PythOracle is OwnableUpgradeable, OracleInterface {
    using SafeMath for uint256;

    // To calculate 10 ** n(which is a signed type)
    using SignedMath for int256;

    // To cast int64/int8 types from Pyth to unsigned types
    using SafeCast for int256;

    /// @notice price decimals
    uint256 public constant EXP_SCALE = 1e18;

    /// @notice the actual pyth oracle address fetch & store the prices
    IPyth public underlyingPythOracle;

    /// @notice emit when setting a new pyth oracle address
    event PythOracleSet(address indexed newPythOracle);

    /// @notice emit when token config added
    event TokenConfigAdded(address indexed vToken, bytes32 indexed pythId, uint64 indexed maxStalePeriod);

    /// @notice token configs by asset address
    mapping(address => TokenConfig) public tokenConfigs;

    modifier notNullAddress(address someone) {
        require(someone != address(0), "can't be zero address");
        _;
    }

    function initialize(address underlyingPythOracle_) public initializer {
        __Ownable_init();
        require(underlyingPythOracle_ != address(0), "pyth oracle cannot be zero address");
        underlyingPythOracle = IPyth(underlyingPythOracle_);
        emit PythOracleSet(underlyingPythOracle_);
    }

    /**
     * @notice Batch set token configs
     * @param tokenConfigs_ token config array
     */
    function setTokenConfigs(TokenConfig[] memory tokenConfigs_) external onlyOwner {
        require(tokenConfigs_.length != 0, "length can't be 0");
        for (uint256 i = 0; i < tokenConfigs_.length; i++) {
            setTokenConfig(tokenConfigs_[i]);
        }
    }

    /**
     * @notice Set single token config, `maxStalePeriod` cannot be 0 and `vToken` can be zero address
     * @param tokenConfig token config struct
     */
    function setTokenConfig(TokenConfig memory tokenConfig) public onlyOwner notNullAddress(tokenConfig.asset) {
        require(tokenConfig.maxStalePeriod != 0, "max stale period cannot be 0");
        tokenConfigs[tokenConfig.asset] = tokenConfig;
        emit TokenConfigAdded(tokenConfig.asset, tokenConfig.pythId, tokenConfig.maxStalePeriod);
    }

    /**
     * @notice set the underlying pyth oracle contract address
     * @param underlyingPythOracle_ pyth oracle contract address
     */
    function setUnderlyingPythOracle(
        IPyth underlyingPythOracle_
    ) external onlyOwner notNullAddress(address(underlyingPythOracle_)) {
        underlyingPythOracle = underlyingPythOracle_;
        emit PythOracleSet(address(underlyingPythOracle_));
    }

    /**
     * @notice Get price of underlying asset of the input vToken, under the hood this function
     * get price from Pyth contract, the prices of which are updated externally
     * @param vToken vToken address
     * @return price in 10 decimals
     */
    function getUnderlyingPrice(address vToken) public view override returns (uint256) {
        require(address(underlyingPythOracle) != address(0), "Pyth oracle is zero address");

        address asset = VBep20Interface(vToken).underlying();
        TokenConfig storage tokenConfig = tokenConfigs[asset];
        require(tokenConfig.asset != address(0), "asset doesn't exist");

        // if the price is expired after it's compared against `maxStalePeriod`, the following call will revert
        PythStructs.Price memory priceInfo = underlyingPythOracle.getPriceNoOlderThan(
            tokenConfig.pythId,
            tokenConfig.maxStalePeriod
        );

        uint256 price = int256(priceInfo.price).toUint256();

        require(price > 0, "Pyth oracle price must be positive");

        // the price returned from Pyth is price ** 10^expo, which is the real dollar price of the assets
        // we need to multiply it by 1e18 to make the price 18 decimals
        BEP20Interface underlyingToken = BEP20Interface(asset);
        if (priceInfo.expo > 0) {
            return
                price.mul(EXP_SCALE).mul(10 ** int256(priceInfo.expo).toUint256()) *
                (10 ** (18 - underlyingToken.decimals()));
        } else {
            return
                price.mul(EXP_SCALE).div(10 ** int256(-priceInfo.expo).toUint256()) *
                (10 ** (18 - underlyingToken.decimals()));
        }
    }
}
