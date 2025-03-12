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

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { DiamondLoupeInterface } from "../interfaces/DiamondLoupeInterface.sol";
import { DiamondCutInterface } from "../interfaces/DiamondCutInterface.sol";
import { ERC165Interface } from "../interfaces/ERC165Interface.sol";
import { OwnershipFacetInterface } from "../interfaces/OwnershipFacetInterface.sol";
import { FundingRateFacetInterface } from "../interfaces/FundingRateFacetInterface.sol";
import { LiquidityFacetInterface } from "../interfaces/LiquidityFacetInterface.sol";
import { GetterFacetInterface } from "../interfaces/GetterFacetInterface.sol";
import { PerpTradeFacetInterface } from "../interfaces/PerpTradeFacetInterface.sol";
import { FarmFacetInterface } from "../interfaces/FarmFacetInterface.sol";

import { AccessControlFacetInterface } from "../interfaces/AccessControlFacetInterface.sol";

/// @title DimaondInitializer - Modified from Nick Mudge's DiamondInit
contract DiamondInitializer {
  // You can add parameters to this function in order to pass in
  // data to set your own state variables
  function initialize() external {
    // adding ERC165 data
    LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

    ds.supportedInterfaces[type(ERC165Interface).interfaceId] = true;
    ds.supportedInterfaces[type(DiamondCutInterface).interfaceId] = true;
    ds.supportedInterfaces[type(DiamondLoupeInterface).interfaceId] = true;
    ds.supportedInterfaces[type(OwnershipFacetInterface).interfaceId] = true;
    ds.supportedInterfaces[type(FundingRateFacetInterface).interfaceId] = true;
    ds.supportedInterfaces[type(LiquidityFacetInterface).interfaceId] = true;
    ds.supportedInterfaces[type(GetterFacetInterface).interfaceId] = true;
    ds.supportedInterfaces[type(PerpTradeFacetInterface).interfaceId] = true;
    ds.supportedInterfaces[type(FarmFacetInterface).interfaceId] = true;
    ds.supportedInterfaces[
      type(AccessControlFacetInterface).interfaceId
    ] = true;
  }
}
