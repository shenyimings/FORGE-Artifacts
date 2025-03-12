// SPDX-License-Identifier: MIT
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
