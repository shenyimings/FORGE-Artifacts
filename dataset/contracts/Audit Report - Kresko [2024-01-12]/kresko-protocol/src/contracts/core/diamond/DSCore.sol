// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC165} from "vendor/IERC165.sol";
import {IDiamondLoupeFacet} from "diamond/interfaces/IDiamondLoupeFacet.sol";
import {IDiamondStateFacet} from "diamond/interfaces/IDiamondStateFacet.sol";
import {IDiamondCutFacet, IExtendedDiamondCutFacet} from "diamond/interfaces/IDiamondCutFacet.sol";

import {Meta} from "libs/Meta.sol";
import {Auth} from "common/Auth.sol";
import {Role, Constants} from "common/Constants.sol";

import {ds, DiamondState} from "diamond/DState.sol";
import {FacetCut, FacetCutAction, Initializer} from "diamond/DSTypes.sol";

library DSCore {
    using DSCore for DiamondState;

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    error DIAMOND_FUNCTION_DOES_NOT_EXIST(bytes4 selector);
    error DIAMOND_INIT_DATA_PROVIDED_BUT_INIT_ADDRESS_WAS_ZERO(bytes data);
    error DIAMOND_INIT_ADDRESS_PROVIDED_BUT_INIT_DATA_WAS_EMPTY(address initializer);
    error DIAMOND_FUNCTION_ALREADY_EXISTS(address newFacet, address oldFacet, bytes4 func);
    error DIAMOND_INIT_FAILED(address initializer, bytes data);
    error DIAMOND_NOT_INITIALIZING();
    error DIAMOND_ALREADY_INITIALIZED(uint256 initializerVersion, uint256 currentVersion);
    error DIAMOND_CUT_ACTION_WAS_NOT_ADD_REPLACE_REMOVE();
    error DIAMOND_FACET_ADDRESS_CANNOT_BE_ZERO_WHEN_ADDING_FUNCTIONS(bytes4[] selectors);
    error DIAMOND_FACET_ADDRESS_CANNOT_BE_ZERO_WHEN_REPLACING_FUNCTIONS(bytes4[] selectors);
    error DIAMOND_FACET_ADDRESS_MUST_BE_ZERO_WHEN_REMOVING_FUNCTIONS(address facet, bytes4[] selectors);
    error DIAMOND_NO_FACET_SELECTORS(address facet);
    error DIAMOND_FACET_ADDRESS_CANNOT_BE_ZERO_WHEN_REMOVING_ONE_FUNCTION(bytes4 selector);
    error DIAMOND_REPLACE_FUNCTION_NEW_FACET_IS_SAME_AS_OLD(address facet, bytes4 selector);
    error NEW_OWNER_CANNOT_BE_ZERO_ADDRESS();
    error NOT_DIAMOND_OWNER(address who, address owner);
    error NOT_PENDING_DIAMOND_OWNER(address who, address pendingOwner);

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Emitted when `execute` is called with some initializer.
     * @dev Overlaps DiamondCut but thats fine as its used by some indexers.
     * @param version Resulting new diamond storage version.
     * @param sender Caller of this execution.
     * @param initializer Contract containing the execution logic.
     * @param data Bytes passed to the initializer contract.
     * @param diamondOwner Diamond owner at the time of execution.
     * @param facetCount Facet count at the time of execution.
     * @param block Block number of the call.
     * @param timestamp Timestamp of the call.
     */
    event InitializerExecuted(
        uint256 indexed version,
        address sender,
        address diamondOwner,
        address initializer,
        bytes data,
        uint256 facetCount,
        uint256 block,
        uint256 timestamp
    );
    event DiamondCut(FacetCut[] diamondCut, address initializer, bytes data);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PendingOwnershipTransfer(address indexed previousOwner, address indexed newOwner);

    /* -------------------------------------------------------------------------- */
    /*                                  Functions                                 */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Setup the DiamondState, add initial facets and execute all initializers.
     * @param _initialFacets Facets to add to the diamond.
     * @param _initializers Initializer contracts to execute.
     * @param _contractOwner Address to set as the contract owner.
     */
    function create(FacetCut[] memory _initialFacets, Initializer[] memory _initializers, address _contractOwner) internal {
        DiamondState storage self = ds();
        if (ds().initialized) revert DIAMOND_ALREADY_INITIALIZED(0, self.storageVersion);
        self.diamondDomainSeparator = Meta.domainSeparator("Kresko Protocol", "V1");
        self.contractOwner = _contractOwner;

        self.supportedInterfaces[type(IDiamondLoupeFacet).interfaceId] = true;
        self.supportedInterfaces[type(IERC165).interfaceId] = true;
        self.supportedInterfaces[type(IDiamondCutFacet).interfaceId] = true;
        self.supportedInterfaces[type(IDiamondStateFacet).interfaceId] = true;
        self.supportedInterfaces[type(IExtendedDiamondCutFacet).interfaceId] = true;

        emit OwnershipTransferred(address(0), _contractOwner);

        Auth._grantRole(Role.DEFAULT_ADMIN, _contractOwner);
        Auth._grantRole(Role.ADMIN, _contractOwner);

        // only cut facets in
        cut(_initialFacets, address(0), "");

        // initializers if there are any
        for (uint256 i; i < _initializers.length; i++) {
            exec(_initializers[i].initContract, _initializers[i].initData);
        }

        self.initialized = true;
    }

    /**
     * @notice Execute some logic on a contract through delegatecall.
     * @param _initializer Contract to delegatecall.
     * @param _calldata Data to pass into the delegatecall.
     */
    function exec(address _initializer, bytes memory _calldata) internal {
        if (_initializer == address(0) && _calldata.length > 0) {
            revert DIAMOND_INIT_DATA_PROVIDED_BUT_INIT_ADDRESS_WAS_ZERO(_calldata);
        }

        if (_initializer != address(0)) {
            if (_calldata.length == 0) {
                revert DIAMOND_INIT_ADDRESS_PROVIDED_BUT_INIT_DATA_WAS_EMPTY(_initializer);
            }
            Meta.enforceHasContractCode(_initializer);

            ds().initializing = Constants.INITIALIZING;
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, bytes memory error) = _initializer.delegatecall(_calldata);
            // pass along failure message from initializer if it reverts
            ds().initializing = Constants.NOT_INITIALIZING;

            if (!success) {
                if (error.length > 0) {
                    // bubble up the error
                    revert(string(error));
                } else {
                    revert DIAMOND_INIT_FAILED(_initializer, _calldata);
                }
            }
            emit InitializerExecuted(
                ++ds().storageVersion,
                msg.sender,
                ds().contractOwner,
                _initializer,
                _calldata,
                ds().facetAddresses.length,
                block.number,
                block.timestamp
            );
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                            Diamond Functionality                           */
    /* -------------------------------------------------------------------------- */

    function cut(FacetCut[] memory _diamondCut, address _initializer, bytes memory _calldata) internal {
        DiamondState storage self = ds();

        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == FacetCutAction.Add) {
                self.addFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == FacetCutAction.Replace) {
                self.replaceFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == FacetCutAction.Remove) {
                self.removeFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else {
                revert DIAMOND_CUT_ACTION_WAS_NOT_ADD_REPLACE_REMOVE();
            }
        }

        emit DiamondCut(_diamondCut, _initializer, _calldata);
        exec(_initializer, _calldata);
    }

    function addFunctions(DiamondState storage self, address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) revert DIAMOND_NO_FACET_SELECTORS(_facetAddress);
        if (_facetAddress == address(0)) {
            revert DIAMOND_FACET_ADDRESS_CANNOT_BE_ZERO_WHEN_ADDING_FUNCTIONS(_functionSelectors);
        }

        uint96 selectorPosition = uint96(self.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            self.addFacet(_facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = self.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress != address(0)) revert DIAMOND_FUNCTION_ALREADY_EXISTS(_facetAddress, oldFacetAddress, selector);
            self.addFunction(selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function replaceFunctions(DiamondState storage self, address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) revert DIAMOND_NO_FACET_SELECTORS(_facetAddress);
        if (_facetAddress == address(0))
            revert DIAMOND_FACET_ADDRESS_CANNOT_BE_ZERO_WHEN_REPLACING_FUNCTIONS(_functionSelectors);

        uint96 selectorPosition = uint96(self.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            self.addFacet(_facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = self.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress == _facetAddress)
                revert DIAMOND_REPLACE_FUNCTION_NEW_FACET_IS_SAME_AS_OLD(_facetAddress, selector);
            self.removeFunction(oldFacetAddress, selector);
            self.addFunction(selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function removeFunctions(DiamondState storage self, address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) revert DIAMOND_NO_FACET_SELECTORS(_facetAddress);
        // if function does not exist then do nothing and return
        if (_facetAddress != address(0)) {
            revert DIAMOND_FACET_ADDRESS_MUST_BE_ZERO_WHEN_REMOVING_FUNCTIONS(_facetAddress, _functionSelectors);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = self.selectorToFacetAndPosition[selector].facetAddress;
            self.removeFunction(oldFacetAddress, selector);
        }
    }

    function addFacet(DiamondState storage self, address _facetAddress) internal {
        Meta.enforceHasContractCode(_facetAddress);
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
        if (_facetAddress == address(0)) {
            revert DIAMOND_FACET_ADDRESS_CANNOT_BE_ZERO_WHEN_REMOVING_ONE_FUNCTION(_selector);
        }
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

    /* -------------------------------------------------------------------------- */
    /*                                  Ownership                                 */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev Initiate ownership transfer to a new address
     * @param _newOwner address that is set as the pending new owner
     * @notice caller must be the current contract owner
     */
    function initiateOwnershipTransfer(DiamondState storage self, address _newOwner) internal {
        if (Meta.msgSender() != self.contractOwner) revert NOT_DIAMOND_OWNER(Meta.msgSender(), self.contractOwner);
        if (_newOwner == address(0)) revert NEW_OWNER_CANNOT_BE_ZERO_ADDRESS();

        self.pendingOwner = _newOwner;

        emit PendingOwnershipTransfer(self.contractOwner, _newOwner);
    }

    /**
     * @dev Transfer the ownership to the new pending owner
     * @notice caller must be the pending owner
     */
    function finalizeOwnershipTransfer(DiamondState storage self) internal {
        address sender = Meta.msgSender();
        if (sender != self.pendingOwner) revert NOT_PENDING_DIAMOND_OWNER(sender, self.pendingOwner);

        self.contractOwner = self.pendingOwner;
        self.pendingOwner = address(0);

        emit OwnershipTransferred(self.contractOwner, sender);
    }
}
