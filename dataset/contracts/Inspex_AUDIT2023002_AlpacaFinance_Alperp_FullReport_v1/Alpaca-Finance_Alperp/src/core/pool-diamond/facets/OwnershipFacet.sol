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
import { OwnershipFacetInterface } from "../interfaces/OwnershipFacetInterface.sol";

contract OwnershipFacet is OwnershipFacetInterface {
  function transferOwnership(address _newOwner) external {
    LibDiamond.enforceIsContractOwner();
    LibDiamond.setContractOwner(_newOwner);
  }

  function owner() external view returns (address owner_) {
    owner_ = LibDiamond.contractOwner();
  }
}
