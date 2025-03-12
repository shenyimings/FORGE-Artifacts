// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import {IDiamondLoupeFacet} from "../interfaces/IDiamondLoupeFacet.sol";
import {ds, DiamondState} from "../DiamondStorage.sol";

contract DiamondLoupeFacet is IDiamondLoupeFacet {
    /// @inheritdoc IDiamondLoupeFacet
    function facets() external view override returns (Facet[] memory facets_) {
        DiamondState storage s = ds();
        uint256 numFacets = s.facetAddresses.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i; i < numFacets; i++) {
            address facetAddress_ = s.facetAddresses[i];
            facets_[i].facetAddress = facetAddress_;
            facets_[i].functionSelectors = s.facetFunctionSelectors[facetAddress_].functionSelectors;
        }
    }

    /// @inheritdoc IDiamondLoupeFacet
    function facetFunctionSelectors(
        address _facet
    ) external view override returns (bytes4[] memory facetFunctionSelectors_) {
        facetFunctionSelectors_ = ds().facetFunctionSelectors[_facet].functionSelectors;
    }

    /// @inheritdoc IDiamondLoupeFacet
    function facetAddresses() external view override returns (address[] memory facetAddresses_) {
        facetAddresses_ = ds().facetAddresses;
    }

    /// @inheritdoc IDiamondLoupeFacet
    function facetAddress(bytes4 _functionSelector) external view override returns (address facetAddress_) {
        facetAddress_ = ds().selectorToFacetAndPosition[_functionSelector].facetAddress;
    }
}
