// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;
import {IDiamondCutFacet} from "../interfaces/IDiamondCutFacet.sol";

import {Meta} from "../../libs/Meta.sol";
import {DiamondEvent} from "../../libs/Events.sol";
import {DiamondState} from "../DiamondState.sol";

// solhint-disable-next-line func-visibility
function initializeDiamondCut(address _init, bytes memory _calldata) {
    if (_init == address(0)) {
        require(_calldata.length == 0, "DiamondCut: _init is address(0) but_calldata is not empty");
    } else {
        require(_calldata.length > 0, "DiamondCut: _calldata is empty but _init is not address(0)");
        Meta.enforceHasContractCode(_init, "DiamondCut: _init address has no code");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                // bubble up the error
                revert(string(error));
            } else {
                revert("DiamondCut: _init function reverted");
            }
        }
    }
}

library LibDiamondCut {
    /* -------------------------------------------------------------------------- */
    /*                              Diamond Functions                             */
    /* -------------------------------------------------------------------------- */

    function diamondCut(
        DiamondState storage self,
        IDiamondCutFacet.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            IDiamondCutFacet.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamondCutFacet.FacetCutAction.Add) {
                self.addFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCutFacet.FacetCutAction.Replace) {
                self.replaceFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCutFacet.FacetCutAction.Remove) {
                self.removeFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else {
                revert("DiamondCut: Incorrect FacetCutAction");
            }
        }
        emit DiamondEvent.DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(
        DiamondState storage self,
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(_functionSelectors.length > 0, "DiamondCut: No selectors in facet to cut");
        require(_facetAddress != address(0), "DiamondCut: Add facet can't be address(0)");
        uint96 selectorPosition = uint96(self.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            self.addFacet(_facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = self.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacetAddress == address(0), "DiamondCut: Can't add function that already exists");
            self.addFunction(selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function replaceFunctions(
        DiamondState storage self,
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(_functionSelectors.length > 0, "DiamondCut: No selectors in facet to cut");
        require(_facetAddress != address(0), "DiamondCut: Add facet can't be address(0)");
        uint96 selectorPosition = uint96(self.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            self.addFacet(_facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = self.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacetAddress != _facetAddress, "DiamondCut: Can't replace function with same function");
            self.removeFunction(oldFacetAddress, selector);
            self.addFunction(selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function removeFunctions(
        DiamondState storage self,
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(_functionSelectors.length > 0, "DiamondCut: No selectors in facet to cut");
        // if function does not exist then do nothing and return
        require(_facetAddress == address(0), "DiamondCut: Remove facet address must be address(0)");
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = self.selectorToFacetAndPosition[selector].facetAddress;
            self.removeFunction(oldFacetAddress, selector);
        }
    }

    function addFacet(DiamondState storage self, address _facetAddress) internal {
        Meta.enforceHasContractCode(_facetAddress, "DiamondCut: New facet has no code");
        self.facetFunctionSelectors[_facetAddress].facetAddressPosition = self.facetAddresses.length;
        self.facetAddresses.push(_facetAddress);
    }

    function addFunction(
        DiamondState storage self,
        bytes4 _selector,
        uint96 _selectorPosition,
        address _facetAddress
    ) internal {
        self.selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        self.facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
        self.selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    function removeFunction(DiamondState storage self, address _facetAddress, bytes4 _selector) internal {
        require(_facetAddress != address(0), "DiamondCut: Can't remove function that doesn't exist");
        // replace selector with last selector, then delete last selector
        uint256 selectorPosition = self.selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = self.facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;
        // if not the same then replace _selector with lastSelector
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = self.facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            self.facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] = lastSelector;
            self.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
        }
        // delete the last selector
        self.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete self.selectorToFacetAndPosition[_selector];

        // if no more selectors for facet address then delete the facet address
        if (lastSelectorPosition == 0) {
            // replace facet address with last facet address and delete last facet address
            uint256 lastFacetAddressPosition = self.facetAddresses.length - 1;
            uint256 facetAddressPosition = self.facetFunctionSelectors[_facetAddress].facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = self.facetAddresses[lastFacetAddressPosition];
                self.facetAddresses[facetAddressPosition] = lastFacetAddress;
                self.facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }
            self.facetAddresses.pop();
            delete self.facetFunctionSelectors[_facetAddress].facetAddressPosition;
        }
    }
}
