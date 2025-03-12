// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface FundingRateFacetInterface {
  function updateFundingRate(address collateralToken, address indexToken)
    external;
}
