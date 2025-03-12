// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IGatewayGuarded.sol";

/**
 * The management interface exposed to gateway.
 */
interface IGatewayGuardedOwnable is IGatewayGuarded {
    /**
     * @dev Reset the owner of the NFT contract.
     * @notice Only gateway contract is authorized to reset a
     * owner in case, for example, the old owner lost his keys.
     * @param newOwner The new owner of the contract.
     */
    function resetOwner(address newOwner) external;
}
