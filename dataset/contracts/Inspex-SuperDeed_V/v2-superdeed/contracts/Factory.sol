// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "./SuperDeedV2.sol";
import "./interfaces/IDeedManager.sol";

contract Factory {
    
    IDeedManager private _manager;

    event CreateDeed(address newDeed, address projectOwner);

    constructor(IDeedManager manager) {
        _manager = manager;
    }

    //--------------------//
    // EXTERNAL FUNCTIONS //
    //--------------------//
    function createNewDeed(address projectOwner, string calldata symbol) external {

        IRoleAccess roles = _manager.getRoles();
        require(roles.isDeployer(msg.sender), "Not deployer");
        require(projectOwner != address(0), "Invalid address");
       
        // Deploy Deed certificate
        string memory deedName = string(abi.encodePacked(symbol, "-Deed")); // Append symbol from XYZ -> XYZ-Deed
        bytes32 salt = keccak256(abi.encodePacked(deedName, _manager.getDeedsCount(), msg.sender));
        address deedAddress = address(new SuperDeedV2{salt:salt}(roles, projectOwner, symbol, deedName)); 
       
        _manager.addDeed(deedAddress, projectOwner);
        emit CreateDeed(deedAddress, projectOwner);
    }

    function version() external pure returns (uint) {
        return Constant.FACTORY_VERSION;
    }
}

