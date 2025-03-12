// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./GatewayGuarded.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * The management interface exposed to gateway.
 */
abstract contract GatewayGuardedOwnable is GatewayGuarded, Ownable {
    function resetOwner(address _newOwner) external onlyGateway {
        _transferOwnership(_newOwner);
    }
}
