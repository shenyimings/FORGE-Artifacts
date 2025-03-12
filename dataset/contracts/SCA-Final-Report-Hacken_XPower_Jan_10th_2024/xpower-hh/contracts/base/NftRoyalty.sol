// SPDX-License-Identifier: GPL-3.0
// solhint-disable not-rely-on-time
pragma solidity ^0.8.20;

import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

import {Supervised, NftRoyaltySupervised} from "./Supervised.sol";

/**
 * Allows changing of the NFT's beneficiary (by the NFT_ROYAL_ROLE) while
 * the default royalty fraction is set to a flat value of 0.5%.
 */
abstract contract NftRoyalty is IERC2981, NftRoyaltySupervised {
    /** address of beneficiary */
    address private _royal;

    constructor() {
        _royal = msg.sender; // fallback beneficiary
    }

    /** @return royalty beneficiary and amount (for nft-id & price) */
    function royaltyInfo(uint256, uint256 price) external view override returns (address, uint256) {
        return (_royal, price / 200);
    }

    /** @return default royalty beneficiary */
    function getRoyal() external view returns (address) {
        return _royal;
    }

    /** set default royalty beneficiary */
    function setRoyal(address beneficiary) external onlyRole(NFT_ROYAL_ROLE) {
        _royal = beneficiary;
    }

    /** @return true if this contract implements the interface defined by interface-id */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, Supervised) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }
}
