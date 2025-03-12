// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";

import {ZeroAddress, CallerNotAdmin} from "../errors/scErrors.sol";
import {Constants as C} from "../lib/Constants.sol";
import {AggregatorV3Interface} from "../interfaces/chainlink/AggregatorV3Interface.sol";
import {IwstETH} from "../interfaces/lido/IwstETH.sol";

/**
 * @title Price Converter
 * @notice Contract for price conversion between assets used by staking vaults.
 */
contract PriceConverter is AccessControl {
    using FixedPointMathLib for uint256;

    IwstETH constant wstETH = IwstETH(C.WSTETH);

    event UsdcToEthPriceFeedUpdated(address indexed admin, address newPriceFeed);
    event StEthToEthPriceFeedUpdated(address indexed admin, address newPriceFeed);

    // Chainlink price feed (USDC -> ETH)
    AggregatorV3Interface public usdcToEthPriceFeed = AggregatorV3Interface(C.CHAINLINK_USDC_ETH_PRICE_FEED);

    // Chainlink price feed (stETH -> ETH)
    AggregatorV3Interface public stEThToEthPriceFeed = AggregatorV3Interface(C.CHAINLINK_STETH_ETH_PRICE_FEED);

    constructor(address _admin) {
        _zeroAddressCheck(_admin);
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function _onlyAdmin() internal view {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert CallerNotAdmin();
    }

    /**
     * @notice Set the chainlink price feed for USDC -> WETH.
     * @param _newPriceFeed The new price feed.
     */
    function setUsdcToEthPriceFeed(address _newPriceFeed) external {
        _onlyAdmin();
        _zeroAddressCheck(_newPriceFeed);

        usdcToEthPriceFeed = AggregatorV3Interface(_newPriceFeed);

        emit UsdcToEthPriceFeedUpdated(msg.sender, address(_newPriceFeed));
    }

    /// @notice Set the chainlink price feed for stETH -> ETH.
    /// @param _newPriceFeed The new price feed.
    function setStEThToEthPriceFeed(address _newPriceFeed) external {
        _onlyAdmin();
        _zeroAddressCheck(_newPriceFeed);

        stEThToEthPriceFeed = AggregatorV3Interface(_newPriceFeed);

        emit StEthToEthPriceFeedUpdated(msg.sender, address(_newPriceFeed));
    }

    /**
     * @notice Returns the USDC fair value for the ETH amount provided.
     * @param _ethAmount The amount of ETH.
     */
    function ethToUsdc(uint256 _ethAmount) public view returns (uint256) {
        (, int256 usdcPriceInEth,,,) = usdcToEthPriceFeed.latestRoundData();

        return _ethAmount.divWadDown(uint256(usdcPriceInEth) * C.WETH_USDC_DECIMALS_DIFF);
    }

    /**
     * @notice Returns the ETH fair value for the USDC amount provided.
     * @param _usdcAmount The amount of USDC.
     */
    function usdcToEth(uint256 _usdcAmount) public view returns (uint256) {
        (, int256 usdcPriceInEth,,,) = usdcToEthPriceFeed.latestRoundData();

        return (_usdcAmount * C.WETH_USDC_DECIMALS_DIFF).mulWadDown(uint256(usdcPriceInEth));
    }

    function ethToWstEth(uint256 ethAmount) public view returns (uint256) {
        (, int256 price,,,) = stEThToEthPriceFeed.latestRoundData();

        uint256 stEthAmount = ethAmount.divWadDown(uint256(price));

        return wstETH.getWstETHByStETH(stEthAmount);
    }

    function stEthToEth(uint256 _stEthAmount) public view returns (uint256) {
        (, int256 price,,,) = stEThToEthPriceFeed.latestRoundData();

        return _stEthAmount.mulWadDown(uint256(price));
    }

    function wstEthToEth(uint256 wstEthAmount) public view returns (uint256) {
        // wstETh to stEth using exchangeRate
        uint256 stEthAmount = wstETH.getStETHByWstETH(wstEthAmount);

        return stEthToEth(stEthAmount);
    }

    function _zeroAddressCheck(address _address) internal pure {
        if (_address == address(0)) revert ZeroAddress();
    }
}
