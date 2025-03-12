// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { PluginBase, PluginCallsConfig } from './PluginBase.sol';
import { Ownable2Step, Ownable } from '@openzeppelin/contracts/access/Ownable2Step.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { EnumerableMap } from '@openzeppelin/contracts/utils/structs/EnumerableMap.sol';
import { EnumerableSet } from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import { Math } from '@openzeppelin/contracts/utils/math/Math.sol';
import { Pausable } from '@openzeppelin/contracts/utils/Pausable.sol';
import { PairLib } from '../libraries/PairLib.sol';
import { PublicOrder } from '../OrderStructs.sol';

/**
 * @notice FeeLevel is a struct that contains a fee percentage and a minimum amount of asset
 * for a fee to be applied. Fee is applied to the amount that is bigger than the minimum amount.
 * @param minAmount minimum amount for a fee level
 * @param fee fee percentage for a fee level
 */
struct FeeLevel {
  uint256 minAmount;
  uint16 fee;
}

/**
 * @notice PairFeeLevels is a struct that contains a pair of assets and a list of fee levels for this pair.
 */
struct PairFeeLevels {
  address asset1;
  address asset2;
  FeeLevel[] feeLevels;
}

/**
 * @notice FeeAggregatorPlugin is a contract that aggregates fees from asset transactions.
 * It allows specifying 3 types of fees: pair fee, asset fee or a default fee.
 * On each trade, FeeAggregator contract checks if there is a fee specified for a given pair.
 * If there's no fee specified for that pair, the contract checks if the asset that fee is about
 * to be paid in has a fee specified. Default fee is used when no fee is specified for a given pair
 * nor for a given asset.
 * @dev Fee percentage is denominated in basis points (1/100th of a percent).
 */
contract FeeAggregatorPlugin is PluginBase, Ownable2Step, Pausable {
  using SafeERC20 for IERC20;
  using EnumerableMap for EnumerableMap.AddressToUintMap;
  using EnumerableSet for EnumerableSet.AddressSet;

  error FeeAggregator__FeeCannotExceedMaxAmount();
  error FeeAggregator__FeeAmountIsBiggerThanAmount();
  error FeeAggregator__NoBaseFeeAmountForPair();
  error FeeAggregator__FeeLevelsAreNotInAscendingOrder();

  event DefaultFeeUpdated(uint16 newfee, uint16 previousFee);
  event FeeForAssetUpdated(address indexed asset, uint16 newfee, uint16 previousFee);
  event FeesWithdrawn(address token, uint256 amount);
  event FeeLevelsForPairUpdated(address indexed assetA, address indexed assetB);

  /// @dev fee cannot exceed 100%
  uint16 public constant BASIS_POINTS_MAX = 10000;
  /// @dev MAX_FEE allowed is 3% in basis points
  uint16 public constant MAX_FEE = 300;
  /// @notice Default fee for each asset. It is used when no fee is specified for a given asset
  uint16 public defaultFee;
  /// @notice Fee that is specific to a given asset. It overrides the default fee.
  EnumerableMap.AddressToUintMap private feeForAsset;
  /// @notice Fees that are specific to a given pair of assets. It overrides the default fee
  /// and a fee that is set for a particular asset.
  mapping(address => mapping(address => FeeLevel[])) public feeForPair;

  constructor(uint16 _defaultFee) Ownable(_msgSender()) {
    defaultFee = _defaultFee;
  }

  // ======== PLUGIN LOGIC ========

  function getCallsConfig() external pure override returns (PluginCallsConfig memory) {
    return
      PluginCallsConfig({
        beforeOrderCreation: false,
        afterOrderCreation: false,
        beforeOrderFill: true,
        afterOrderFill: false,
        beforeOrderCancel: false,
        afterOrderCancel: false
      });
  }

  /**
   * @notice Calculates the fee amount based on the specfied fee params and deducts it from the maker sell token
   * so the filler will receive less tokens. It does not apply any fee for the maker.
   * @param order order that will have fee applied
   */
  function beforeOrderFill(
    PublicOrder memory order
  ) external view override returns (PublicOrder memory) {
    if (paused()) {
      return order;
    }

    uint256 feeAmount = _calculateFeeAmount(
      order.makerSellToken,
      order.makerBuyToken,
      order.makerSellTokenAmount
    );

    // deduct fee from the order
    order.makerSellTokenAmount = order.makerSellTokenAmount - feeAmount;

    return order;
  }

  // ======== DOMAIN LOGIC ========

  /**
   * @notice Sets the default fee for all assets.
   * @param fee fee in basis points (1/100th of a percent)
   */
  function setDefaultFee(uint16 fee) external onlyOwner {
    if (fee > MAX_FEE) {
      revert FeeAggregator__FeeCannotExceedMaxAmount();
    }
    defaultFee = fee;
    emit DefaultFeeUpdated(fee, defaultFee);
  }

  /**
   * @notice Sets the fee for a given asset.
   * @param asset asset address
   * @param fee fee in basis points (1/100th of a percent)
   */
  function setFeeForAsset(address asset, uint16 fee) external onlyOwner {
    if (fee > MAX_FEE) {
      revert FeeAggregator__FeeCannotExceedMaxAmount();
    }
    feeForAsset.set(asset, fee);
    emit FeeForAssetUpdated(asset, fee, defaultFee);
  }

  /**
   * @notice Sets the fee levels for a given pair of assets.
   * @param _asset1 first asset address
   * @param _asset2 second asset address
   * @param feeLevels array of fee levels. First element should describe a fee when swap amount is 0.
   */
  function setFeeLevelsForPair(
    address _asset1,
    address _asset2,
    FeeLevel[] calldata feeLevels
  ) external onlyOwner {
    (address asset1, address asset2) = PairLib.getPairInOrder(_asset1, _asset2);

    uint256 amountOfFeeLevels = feeLevels.length;

    // remove fee levels for a given pair if feeLevels array is empty
    if (amountOfFeeLevels == 0) {
      feeForPair[asset1][asset2] = new FeeLevel[](0);
      emit FeeLevelsForPairUpdated(asset1, asset2);
      return;
    }

    if (feeLevels[0].minAmount != 0) {
      revert FeeAggregator__NoBaseFeeAmountForPair();
    }

    for (uint256 i = 0; i < amountOfFeeLevels; ++i) {
      if (feeLevels[i].fee > MAX_FEE) {
        revert FeeAggregator__FeeCannotExceedMaxAmount();
      }
      if (i > 0) {
        if (feeLevels[i].minAmount <= feeLevels[i - 1].minAmount) {
          revert FeeAggregator__FeeLevelsAreNotInAscendingOrder();
        }
      }
    }

    feeForPair[asset1][asset2] = feeLevels;
    emit FeeLevelsForPairUpdated(asset1, asset2);
  }

  /**
   * @notice Returns the fee for a given asset. If there's no fee for a given asset, the default fee
   * is returned.
   * @param asset asset address
   * @return fee for a given asset
   */
  function getFeeForAsset(address asset) public view returns (uint16) {
    if (paused()) {
      return 0;
    }

    if (feeForAsset.contains(asset)) {
      return uint16(feeForAsset.get(asset));
    }
    return defaultFee;
  }

  /**
   * @notice Returns the fee levels for a given pair of assets. If there's no fee for a given pair,
   * empty array is returned.
   * @param _asset1 first asset address
   * @param _asset2 second asset address
   * @return feeLevels fee levels for a given pair of assets
   */
  function getFeeLevelsForPair(
    address _asset1,
    address _asset2
  ) public view returns (FeeLevel[] memory feeLevels) {
    if (paused()) {
      return new FeeLevel[](0);
    }
    (address asset1, address asset2) = PairLib.getPairInOrder(_asset1, _asset2);
    return feeForPair[asset1][asset2];
  }

  /**
   * @notice Calculates the fee amount for a given asset and input amount.
   * @param assetPayableAsFee token address in which the fee is paid
   * @param secondAsset second token address
   * @param amount amount of fee
   */
  function _calculateFeeAmount(
    address assetPayableAsFee,
    address secondAsset,
    uint256 amount
  ) internal view returns (uint256 feeAmount) {
    uint16 fee = 0;

    // first check if there's a fee for a given pair
    (address asset1, address asset2) = PairLib.getPairInOrder(
      assetPayableAsFee,
      secondAsset
    );
    FeeLevel[] memory feeLevels = feeForPair[asset1][asset2];
    uint256 amountOfFeeLevels = feeLevels.length;

    if (amountOfFeeLevels != 0) {
      uint16 lowestFee = feeLevels[0].fee;
      // Iterate through the feeLevels array and find the appropriate fee level based on the amount
      for (uint256 i = 0; i < amountOfFeeLevels; ++i) {
        if (amount >= feeLevels[i].minAmount) {
          if (feeLevels[i].fee < lowestFee) {
            lowestFee = feeLevels[i].fee;
          }
        }
      }
      fee = lowestFee;
    } else {
      // if there's no fee for a given pair, check if there's a fee for a given asset
      // if there's no fee for a given asset, getFeeForAsset returns the default fee
      fee = getFeeForAsset(assetPayableAsFee);
    }

    if (fee == 0) {
      return 0;
    }

    feeAmount = (amount * fee) / BASIS_POINTS_MAX;
    if (feeAmount > amount) {
      revert FeeAggregator__FeeAmountIsBiggerThanAmount();
    }
  }

  /**
   * @notice Allows the owner to temporarily pause collecting fees.
   */
  function pauseCollectingFees() external onlyOwner {
    _pause();
  }

  /**
   * @notice Allows the owner to unpause collecting fees.
   */
  function unpauseCollectingFees() external onlyOwner {
    _unpause();
  }
}
