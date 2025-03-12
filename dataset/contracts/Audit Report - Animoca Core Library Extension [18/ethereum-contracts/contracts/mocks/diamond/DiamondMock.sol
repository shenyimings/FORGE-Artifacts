// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {FacetCutAction, FacetCut, Initialization} from "./../../diamond/DiamondCommon.sol";
import {DiamondStorage} from "./../../diamond/libraries/DiamondStorage.sol";
import {Diamond} from "./../../diamond/Diamond.sol";

contract DiamondMock is Diamond {
    using DiamondStorage for DiamondStorage.Layout;

    event ImmutableFunctionCalled();

    constructor(FacetCut[] memory cuts, Initialization[] memory initializations) payable Diamond(cuts, initializations) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = DiamondMock.immutableFunction.selector;
        FacetCut[] memory cut = new FacetCut[](1);
        cut[0].facet = address(this);
        cut[0].action = FacetCutAction.ADD;
        cut[0].selectors = selectors;

        DiamondStorage.layout().diamondCut(cut, address(0), "");
    }

    function immutableFunction() external {
        emit ImmutableFunctionCalled();
    }
}
