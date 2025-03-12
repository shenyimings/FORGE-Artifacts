// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";
import { SafeCastUpgradeable } from "@openzeppelin-upgradeable/utils/math/SafeCastUpgradeable.sol";

// interfaces
import { IChainlinkAggregator } from "src/interfaces/IChainlinkAggregator.sol";

abstract contract BaseOracle is Ownable2StepUpgradeable {
  /// Libraries
  using SafeCastUpgradeable for int256;

  /// Errors
  error BaseOracle_PriceTooOld();
  error BaseOracle_InvalidPrice();

  /// Events
  event LogSetMaxPriceAge(uint16 prevMaxPriceAge, uint16 maxPriceAge);
  event LogSetPriceFeedOf(address indexed token, address prevPriceFeed, address priceFeed);

  /// States
  uint16 public maxPriceAge;
  mapping(address => IChainlinkAggregator) public priceFeedOf;

  /// @notice Set price feed of a token.
  /// @param _token Token address.
  /// @param _newPriceFeed New price feed address.
  function setPriceFeedOf(address _token, address _newPriceFeed) external onlyOwner {
    // Sanity check
    IChainlinkAggregator(_newPriceFeed).latestRoundData();

    emit LogSetPriceFeedOf(_token, address(priceFeedOf[_token]), _newPriceFeed);
    priceFeedOf[_token] = IChainlinkAggregator(_newPriceFeed);
  }

  /// @notice Set max price age.
  /// @param _newMaxPriceAge Max price age in seconds.
  function setMaxPriceAge(uint16 _newMaxPriceAge) external onlyOwner {
    emit LogSetMaxPriceAge(maxPriceAge, _newMaxPriceAge);
    maxPriceAge = _newMaxPriceAge;
  }

  /// @notice Fetch token price from price feed. Revert if price too old or negative.
  /// @param _token Token address.
  /// @return _price Price of the token in 18 decimals.
  function _safeGetTokenPriceE18(address _token) internal view returns (uint256 _price) {
    // SLOAD
    IChainlinkAggregator _priceFeed = priceFeedOf[_token];
    (, int256 _answer,, uint256 _updatedAt,) = _priceFeed.latestRoundData();
    // Safe to use unchecked since `block.timestamp` will at least equal to `_updatedAt` in the same block
    // even somehow it underflows it would revert anyway
    unchecked {
      if (block.timestamp - _updatedAt > maxPriceAge) {
        revert BaseOracle_PriceTooOld();
      }
    }
    if (_answer <= 0) {
      revert BaseOracle_InvalidPrice();
    }
    // Normalize to 18 decimals
    return _answer.toUint256() * (10 ** (18 - _priceFeed.decimals()));
  }

  function getTokenPrice(address _token) external view returns (uint256 _price) {
    _price = _safeGetTokenPriceE18(_token);
  }
}
