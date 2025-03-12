// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Ingest Registry Contract
 * @author Origin Protocol Inc
 */

import "../governance/Governable.sol";

contract IngestRegistry is Governable {
    address public endpointImplementation;
    address public master;
    address public pool;

    event NewEndpointImplementation(
        address indexed newCollector,
        address indexed oldCollector
    );

    event NewMaster(address indexed newMaster, address indexed oldMaster);

    event NewPool(address indexed newPool, address indexed oldPool);

    function setEndpointImplementation(address addr) external onlyGovernor {
        emit NewEndpointImplementation(addr, endpointImplementation);
        endpointImplementation = addr;
    }

    function setMaster(address addr) external onlyGovernor {
        emit NewMaster(addr, master);
        master = addr;
    }

    function setPool(address addr) external onlyGovernor {
        emit NewPool(addr, pool);
        pool = addr;
    }
}
