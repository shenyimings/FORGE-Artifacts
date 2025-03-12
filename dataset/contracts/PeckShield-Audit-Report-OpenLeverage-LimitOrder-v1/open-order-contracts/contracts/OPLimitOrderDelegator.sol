// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import "./Adminable.sol";
import "./DelegatorInterface.sol";
import "./interfaces/DexAggregatorInterface.sol";
import "./interfaces/OpenLevInterface.sol";

contract OPLimitOrderDelegator is DelegatorInterface, Adminable {
    constructor(
        OpenLevInterface _openLev,
        DexAggregatorInterface _dexAgg,
        address payable _admin,
        address implementation_
    ) {
        admin = payable(msg.sender);
        // Creator of the contract is admin during initialization
        // First delegate gets to initialize the delegator (i.e. storage contract)
        delegateTo(implementation_, abi.encodeWithSignature("initialize(address,address)", _openLev, _dexAgg));
        implementation = implementation_;

        // Set the proper admin now that initialization is done
        admin = _admin;
    }

    /**
     * Called by the admin to update the implementation of the delegator
     * @param implementation_ The address of the new implementation for delegation
     */
    function setImplementation(address implementation_) public override onlyAdmin {
        address oldImplementation = implementation;
        implementation = implementation_;
        emit NewImplementation(oldImplementation, implementation);
    }
}
