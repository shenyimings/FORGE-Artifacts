// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
pragma experimental ABIEncoderV2;

// solhint-disable-next-line max-line-length
import {EmptyFacet, NonContractFacet, FunctionAlreadyPresent, RemovingWithNonZeroAddressFacet, FunctionNotFound, ModifyingImmutableFunction, ReplacingFunctionByItself, ZeroAddressTargetInitCallButNonEmptyData, EmptyInitCallData, NonContractInitCallTarget, InitCallReverted} from "./../errors/DiamondErrors.sol";
import {Facet, FacetCutAction, FacetCut, Initialization} from "./../DiamondCommon.sol";
import {DiamondCut} from "./../events/DiamondCutEvents.sol";
import {IDiamondCut} from "./../interfaces/IDiamondCut.sol";
import {IDiamondCutBatchInit} from "./../interfaces/IDiamondCutBatchInit.sol";
import {IDiamondLoupe} from "./../interfaces/IDiamondLoupe.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {InterfaceDetectionStorage} from "./../../introspection/libraries/InterfaceDetectionStorage.sol";

/// @dev derived from https://github.com/mudgen/diamond-2 (MIT licence) and https://github.com/solidstate-network/solidstate-solidity (MIT licence)
library DiamondStorage {
    using Address for address;
    using DiamondStorage for DiamondStorage.Layout;
    using InterfaceDetectionStorage for InterfaceDetectionStorage.Layout;

    struct Layout {
        // selector => (facet address, selector slot position)
        mapping(bytes4 => bytes32) diamondFacets;
        // number of selectors registered in selectorSlots
        uint16 selectorCount;
        // array of selector slots with 8 selectors per slot
        mapping(uint256 => bytes32) selectorSlots;
    }

    bytes32 internal constant LAYOUT_STORAGE_SLOT = bytes32(uint256(keccak256("animoca.core.Diamond.storage")) - 1);

    bytes32 internal constant CLEAR_ADDRESS_MASK = bytes32(uint256(0xffffffffffffffffffffffff));
    bytes32 internal constant CLEAR_SELECTOR_MASK = bytes32(uint256(0xffffffff << 224));

    /// @notice Marks the following ERC165 interface(s) as supported: DiamondCut, DiamondCutBatchInit.
    function initDiamondCut() internal {
        InterfaceDetectionStorage.Layout storage interfaceDetectionLayout = InterfaceDetectionStorage.layout();
        interfaceDetectionLayout.setSupportedInterface(type(IDiamondCut).interfaceId, true);
        interfaceDetectionLayout.setSupportedInterface(type(IDiamondCutBatchInit).interfaceId, true);
    }

    /// @notice Marks the following ERC165 interface(s) as supported: DiamondLoupe.
    function initDiamondLoupe() internal {
        InterfaceDetectionStorage.layout().setSupportedInterface(type(IDiamondLoupe).interfaceId, true);
    }

    function diamondCut(Layout storage s, FacetCut[] memory cuts, address target, bytes memory data) internal {
        s.cutFacets(cuts);
        initializationCall(target, data);
        emit DiamondCut(cuts, target, data);
    }

    function diamondCut(Layout storage s, FacetCut[] memory cuts, Initialization[] memory initializations) internal {
        s.cutFacets(cuts);
        uint256 length = initializations.length;
        for (uint256 i; i < length; ++i) {
            initializationCall(initializations[i].target, initializations[i].data);
        }
        emit DiamondCut(cuts, address(0), "");
    }

    function cutFacets(Layout storage s, FacetCut[] memory facetCuts) internal {
        uint256 originalSelectorCount = s.selectorCount;
        uint256 selectorCount = originalSelectorCount;
        bytes32 selectorSlot;

        // Check if last selector slot is not full
        if (selectorCount & 7 > 0) {
            // get last selectorSlot
            selectorSlot = s.selectorSlots[selectorCount >> 3];
        }

        uint256 length = facetCuts.length;
        for (uint256 i; i < length; ++i) {
            FacetCut memory facetCut = facetCuts[i];

            if (facetCut.selectors.length == 0) revert EmptyFacet(facetCut.facet);

            FacetCutAction action = facetCut.action;
            if (action == FacetCutAction.ADD) {
                (selectorCount, selectorSlot) = s.addFacetSelectors(selectorCount, selectorSlot, facetCut);
            } else if (action == FacetCutAction.REPLACE) {
                s.replaceFacetSelectors(facetCut);
            } else {
                (selectorCount, selectorSlot) = s.removeFacetSelectors(selectorCount, selectorSlot, facetCut);
            }
        }

        if (selectorCount != originalSelectorCount) {
            s.selectorCount = uint16(selectorCount);
        }

        // If last selector slot is not full
        if (selectorCount & 7 > 0) {
            s.selectorSlots[selectorCount >> 3] = selectorSlot;
        }
    }

    function addFacetSelectors(
        Layout storage s,
        uint256 selectorCount,
        bytes32 selectorSlot,
        FacetCut memory facetCut
    ) internal returns (uint256, bytes32) {
        if (facetCut.facet != address(this) && !facetCut.facet.isContract()) revert NonContractFacet(facetCut.facet);

        uint256 length = facetCut.selectors.length;
        for (uint256 i; i < length; ++i) {
            bytes4 selector = facetCut.selectors[i];
            address oldFacetAddress = address(bytes20(s.diamondFacets[selector]));

            if (oldFacetAddress != address(0)) revert FunctionAlreadyPresent(oldFacetAddress, selector);

            // add facet for selector
            s.diamondFacets[selector] = bytes20(facetCut.facet) | bytes32(selectorCount);
            uint256 selectorInSlotPosition = (selectorCount & 7) << 5;

            // clear selector position in slot and add selector
            selectorSlot = (selectorSlot & ~(CLEAR_SELECTOR_MASK >> selectorInSlotPosition)) | (bytes32(selector) >> selectorInSlotPosition);

            // if slot is full then write it to storage
            if (selectorInSlotPosition == 224) {
                s.selectorSlots[selectorCount >> 3] = selectorSlot;
                selectorSlot = 0;
            }

            unchecked {
                ++selectorCount;
            }
        }

        return (selectorCount, selectorSlot);
    }

    function removeFacetSelectors(
        Layout storage s,
        uint256 selectorCount,
        bytes32 selectorSlot,
        FacetCut memory facetCut
    ) internal returns (uint256, bytes32) {
        if (facetCut.facet != address(0)) revert RemovingWithNonZeroAddressFacet(facetCut.facet);

        uint256 selectorSlotCount = selectorCount >> 3;
        uint256 selectorInSlotIndex = selectorCount & 7;

        for (uint256 i; i < facetCut.selectors.length; ++i) {
            bytes4 selector = facetCut.selectors[i];
            bytes32 oldFacet = s.diamondFacets[selector];

            if (address(bytes20(s.diamondFacets[selector])) == address(0)) revert FunctionNotFound(selector);
            if (address(bytes20(s.diamondFacets[selector])) == address(this)) revert ModifyingImmutableFunction(selector);

            if (selectorSlot == 0) {
                unchecked {
                    selectorSlotCount--;
                }
                selectorSlot = s.selectorSlots[selectorSlotCount];
                selectorInSlotIndex = 7;
            } else {
                unchecked {
                    selectorInSlotIndex--;
                }
            }

            bytes4 lastSelector;
            uint256 oldSelectorsSlotCount;
            uint256 oldSelectorInSlotPosition;

            // adding a block here prevents stack too deep error
            {
                // replace selector with last selector in l.facets
                lastSelector = bytes4(selectorSlot << (selectorInSlotIndex << 5));

                if (lastSelector != selector) {
                    // update last selector slot position info
                    s.diamondFacets[lastSelector] = (oldFacet & CLEAR_ADDRESS_MASK) | bytes20(s.diamondFacets[lastSelector]);
                }

                delete s.diamondFacets[selector];
                uint256 oldSelectorCount = uint16(uint256(oldFacet));
                oldSelectorsSlotCount = oldSelectorCount >> 3;
                oldSelectorInSlotPosition = (oldSelectorCount & 7) << 5;
            }

            if (oldSelectorsSlotCount != selectorSlotCount) {
                bytes32 oldSelectorSlot = s.selectorSlots[oldSelectorsSlotCount];

                // clears the selector we are deleting and puts the last selector in its place.
                oldSelectorSlot =
                    (oldSelectorSlot & ~(CLEAR_SELECTOR_MASK >> oldSelectorInSlotPosition)) |
                    (bytes32(lastSelector) >> oldSelectorInSlotPosition);

                // update storage with the modified slot
                s.selectorSlots[oldSelectorsSlotCount] = oldSelectorSlot;
            } else {
                // clears the selector we are deleting and puts the last selector in its place.
                selectorSlot =
                    (selectorSlot & ~(CLEAR_SELECTOR_MASK >> oldSelectorInSlotPosition)) |
                    (bytes32(lastSelector) >> oldSelectorInSlotPosition);
            }

            if (selectorInSlotIndex == 0) {
                delete s.selectorSlots[selectorSlotCount];
                selectorSlot = 0;
            }
        }

        selectorCount = (selectorSlotCount << 3) | selectorInSlotIndex;

        return (selectorCount, selectorSlot);
    }

    function replaceFacetSelectors(Layout storage s, FacetCut memory facetCut) internal {
        address facet = facetCut.facet;
        if (!facet.isContract()) revert NonContractFacet(facetCut.facet);

        uint256 length = facetCut.selectors.length;
        for (uint256 i; i < length; ++i) {
            bytes4 selector = facetCut.selectors[i];
            bytes32 oldFacet = s.diamondFacets[selector];
            address oldFacetAddress = address(bytes20(oldFacet));

            if (oldFacetAddress == address(0)) revert FunctionNotFound(selector);
            if (oldFacetAddress == address(this)) revert ModifyingImmutableFunction(selector);
            if (oldFacetAddress == facet) revert ReplacingFunctionByItself(facet, selector);

            // replace old facet address
            s.diamondFacets[selector] = (oldFacet & CLEAR_ADDRESS_MASK) | bytes20(facet);
        }
    }

    function initializationCall(address target, bytes memory data) internal {
        if (target == address(0)) {
            if (data.length != 0) revert ZeroAddressTargetInitCallButNonEmptyData();
        } else {
            if (data.length == 0) revert EmptyInitCallData(target);
            if (target != address(this)) {
                if (!target.isContract()) revert NonContractInitCallTarget(target);
            }

            (bool success, bytes memory returndata) = target.delegatecall(data);
            if (!success) {
                uint256 returndataLength = returndata.length;
                if (returndataLength != 0) {
                    assembly {
                        revert(add(32, returndata), returndataLength)
                    }
                } else {
                    revert InitCallReverted(target, data);
                }
            }
        }
    }

    function delegateOnFallback(Layout storage s) internal {
        bytes4 selector = msg.sig;
        address facet = s.facetAddress(selector);
        if (facet == address(0)) revert FunctionNotFound(selector);
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function facets(Layout storage s) internal view returns (Facet[] memory diamondFacets) {
        unchecked {
            uint16 selectorCount = s.selectorCount;
            diamondFacets = new Facet[](selectorCount);

            uint256[] memory numFacetSelectors = new uint256[](selectorCount);
            uint256 numFacets;
            uint256 selectorIndex;

            // loop through function selectors
            for (uint256 slotIndex; selectorIndex < selectorCount; ++slotIndex) {
                bytes32 slot = s.selectorSlots[slotIndex];

                for (uint256 selectorSlotIndex; selectorSlotIndex != 8; ++selectorSlotIndex) {
                    ++selectorIndex;

                    if (selectorIndex > selectorCount) {
                        break;
                    }

                    bytes4 selector = bytes4(slot << (selectorSlotIndex << 5));
                    address facet = address(bytes20(s.diamondFacets[selector]));

                    bool continueLoop;

                    for (uint256 facetIndex; facetIndex != numFacets; ++facetIndex) {
                        if (diamondFacets[facetIndex].facet == facet) {
                            diamondFacets[facetIndex].selectors[numFacetSelectors[facetIndex]] = selector;
                            ++numFacetSelectors[facetIndex];
                            continueLoop = true;
                            break;
                        }
                    }

                    if (continueLoop) {
                        continue;
                    }

                    diamondFacets[numFacets].facet = facet;
                    diamondFacets[numFacets].selectors = new bytes4[](selectorCount);
                    diamondFacets[numFacets].selectors[0] = selector;
                    numFacetSelectors[numFacets] = 1;
                    ++numFacets;
                }
            }

            for (uint256 facetIndex; facetIndex < numFacets; ++facetIndex) {
                uint256 numSelectors = numFacetSelectors[facetIndex];
                bytes4[] memory selectors = diamondFacets[facetIndex].selectors;

                // setting the number of selectors
                assembly {
                    mstore(selectors, numSelectors)
                }
            }

            // setting the number of facets
            assembly {
                mstore(diamondFacets, numFacets)
            }
        }
    }

    function facetFunctionSelectors(Layout storage s, address facet) internal view returns (bytes4[] memory selectors) {
        unchecked {
            uint16 selectorCount = s.selectorCount;
            selectors = new bytes4[](selectorCount);

            uint256 numSelectors;
            uint256 selectorIndex;

            // loop through function selectors
            for (uint256 slotIndex; selectorIndex < selectorCount; ++slotIndex) {
                bytes32 slot = s.selectorSlots[slotIndex];

                for (uint256 selectorSlotIndex; selectorSlotIndex != 8; ++selectorSlotIndex) {
                    ++selectorIndex;

                    if (selectorIndex > selectorCount) {
                        break;
                    }

                    bytes4 selector = bytes4(slot << (selectorSlotIndex << 5));

                    if (facet == address(bytes20(s.diamondFacets[selector]))) {
                        selectors[numSelectors] = selector;
                        ++numSelectors;
                    }
                }
            }

            // set the number of selectors in the array
            assembly {
                mstore(selectors, numSelectors)
            }
        }
    }

    function facetAddresses(Layout storage s) internal view returns (address[] memory addresses) {
        unchecked {
            uint16 selectorCount = s.selectorCount;
            addresses = new address[](selectorCount);
            uint256 numFacets;
            uint256 selectorIndex;

            for (uint256 slotIndex; selectorIndex < selectorCount; ++slotIndex) {
                bytes32 slot = s.selectorSlots[slotIndex];

                for (uint256 selectorSlotIndex; selectorSlotIndex != 8; ++selectorSlotIndex) {
                    ++selectorIndex;

                    if (selectorIndex > selectorCount) {
                        break;
                    }

                    bytes4 selector = bytes4(slot << (selectorSlotIndex << 5));
                    address facet = address(bytes20(s.diamondFacets[selector]));

                    bool continueLoop;

                    for (uint256 facetIndex; facetIndex < numFacets; ++facetIndex) {
                        if (facet == addresses[facetIndex]) {
                            continueLoop = true;
                            break;
                        }
                    }

                    if (continueLoop) {
                        continue;
                    }

                    addresses[numFacets] = facet;
                    ++numFacets;
                }
            }

            // set the number of facet addresses in the array
            assembly {
                mstore(addresses, numFacets)
            }
        }
    }

    function facetAddress(Layout storage s, bytes4 selector) internal view returns (address facet) {
        facet = address(bytes20(s.diamondFacets[selector]));
    }

    function layout() internal pure returns (Layout storage s) {
        bytes32 position = LAYOUT_STORAGE_SLOT;
        assembly {
            s.slot := position
        }
    }
}
