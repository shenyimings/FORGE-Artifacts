// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/
pragma solidity 0.8.17;

import { LibPoolV1 } from "../libraries/LibPoolV1.sol";
import { LibPoolConfigV1 } from "../libraries/LibPoolConfigV1.sol";

import { FundingRateFacetInterface } from "../interfaces/FundingRateFacetInterface.sol";
import { GetterFacetInterface } from "../interfaces/GetterFacetInterface.sol";

contract FundingRateFacet is FundingRateFacetInterface {
  event UpdateBorrowingRate(address token, uint256 sumBorrowingRate);
  event UpdateFundingRate(
    address token,
    int256 sumRateLong,
    int256 sumRateShort
  );

  function updateFundingRate(address collateralToken, address indexToken)
    external
  {
    _updateBorrowingRateAndFundingRate(collateralToken);
    if (collateralToken != indexToken)
      _updateBorrowingRateAndFundingRate(indexToken);
  }

  function _updateBorrowingRateAndFundingRate(address token) internal {
    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();

    uint256 fundingInterval = LibPoolConfigV1.fundingInterval();

    // If this is the first time that the funding and borrowing rate are accrued,
    // set the initial funding time here
    if (poolV1ds.lastFundingTimeOf[token] == 0) {
      poolV1ds.lastFundingTimeOf[token] =
        (block.timestamp / fundingInterval) *
        fundingInterval;
      return;
    }

    // If block.timestamp is not passed the next funding interval, skip updating
    if (
      poolV1ds.lastFundingTimeOf[token] + fundingInterval <= block.timestamp
    ) {
      //update borrowing rate
      uint256 borrowingRate = GetterFacetInterface(address(this))
        .getNextBorrowingRate(token);
      unchecked {
        poolV1ds.sumBorrowingRateOf[token] += borrowingRate;
      }

      emit UpdateBorrowingRate(token, poolV1ds.sumBorrowingRateOf[token]);

      // update funding rate
      (int256 fundingRateLong, int256 fundingRateShort) = GetterFacetInterface(
        address(this)
      ).getNextFundingRate(token);
      unchecked {
        poolV1ds.accumFundingRateLong[token] += fundingRateLong;
        poolV1ds.accumFundingRateShort[token] += fundingRateShort;
        poolV1ds.lastFundingTimeOf[token] =
          (block.timestamp / fundingInterval) *
          fundingInterval;
      }

      emit UpdateFundingRate(
        token,
        poolV1ds.accumFundingRateLong[token],
        poolV1ds.accumFundingRateShort[token]
      );
    }
  }
}
