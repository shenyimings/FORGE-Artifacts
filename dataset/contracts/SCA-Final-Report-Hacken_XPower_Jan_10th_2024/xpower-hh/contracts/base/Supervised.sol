// SPDX-License-Identifier: GPL-3.0
// solhint-disable one-contract-per-file
pragma solidity ^0.8.20;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

abstract contract Supervised is AccessControlEnumerable {
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /** @return true if this contract implements the interface defined by interface-id */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

abstract contract MoeTreasurySupervised is Supervised {
    /** role grants right to change APR parametrization */
    bytes32 public constant APR_ROLE = keccak256("APR_ROLE");
    bytes32 public constant APR_ADMIN_ROLE = keccak256("APR_ADMIN_ROLE");
    /** role grants right to change APB parametrization */
    bytes32 public constant APB_ROLE = keccak256("APB_ROLE");
    bytes32 public constant APB_ADMIN_ROLE = keccak256("APB_ADMIN_ROLE");

    constructor() {
        _setRoleAdmin(APR_ROLE, APR_ADMIN_ROLE);
        _grantRole(APR_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(APB_ROLE, APB_ADMIN_ROLE);
        _grantRole(APB_ADMIN_ROLE, msg.sender);
    }
}

abstract contract MoeMigratableSupervised is Supervised {
    /** role grants right to seal MOE immigration */
    bytes32 public constant MOE_SEAL_ROLE = keccak256("MOE_SEAL_ROLE");
    bytes32 public constant MOE_SEAL_ADMIN_ROLE = keccak256("MOE_SEAL_ADMIN_ROLE");

    constructor() {
        _setRoleAdmin(MOE_SEAL_ROLE, MOE_SEAL_ADMIN_ROLE);
        _grantRole(MOE_SEAL_ADMIN_ROLE, msg.sender);
    }
}

abstract contract SovMigratableSupervised is Supervised {
    /** role grants right to seal SOV immigration */
    bytes32 public constant SOV_SEAL_ROLE = keccak256("SOV_SEAL_ROLE");
    bytes32 public constant SOV_SEAL_ADMIN_ROLE = keccak256("SOV_SEAL_ADMIN_ROLE");

    constructor() {
        _setRoleAdmin(SOV_SEAL_ROLE, SOV_SEAL_ADMIN_ROLE);
        _grantRole(SOV_SEAL_ADMIN_ROLE, msg.sender);
    }
}

abstract contract NftMigratableSupervised is Supervised {
    /** role grants right to seal NFT immigration */
    bytes32 public constant NFT_SEAL_ROLE = keccak256("NFT_SEAL_ROLE");
    bytes32 public constant NFT_SEAL_ADMIN_ROLE = keccak256("NFT_SEAL_ADMIN_ROLE");
    /** role grants right to open NFT emigration */
    bytes32 public constant NFT_OPEN_ROLE = keccak256("NFT_OPEN_ROLE");
    bytes32 public constant NFT_OPEN_ADMIN_ROLE = keccak256("NFT_OPEN_ADMIN_ROLE");

    constructor() {
        _setRoleAdmin(NFT_SEAL_ROLE, NFT_SEAL_ADMIN_ROLE);
        _grantRole(NFT_SEAL_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(NFT_OPEN_ROLE, NFT_OPEN_ADMIN_ROLE);
        _grantRole(NFT_OPEN_ADMIN_ROLE, msg.sender);
    }
}

abstract contract NftRoyaltySupervised is Supervised {
    /** role grants right to set the NFT's default royalty beneficiary */
    bytes32 public constant NFT_ROYAL_ROLE = keccak256("NFT_ROYAL_ROLE");
    bytes32 public constant NFT_ROYAL_ADMIN_ROLE = keccak256("NFT_ROYAL_ADMIN_ROLE");

    constructor() {
        _setRoleAdmin(NFT_ROYAL_ROLE, NFT_ROYAL_ADMIN_ROLE);
        _grantRole(NFT_ROYAL_ADMIN_ROLE, msg.sender);
    }
}

abstract contract URIMalleableSupervised is Supervised {
    /** role grants right to change metadata URIs */
    bytes32 public constant URI_DATA_ROLE = keccak256("URI_DATA_ROLE");
    bytes32 public constant URI_DATA_ADMIN_ROLE = keccak256("URI_DATA_ADMIN_ROLE");

    constructor() {
        _setRoleAdmin(URI_DATA_ROLE, URI_DATA_ADMIN_ROLE);
        _grantRole(URI_DATA_ADMIN_ROLE, msg.sender);
    }
}
