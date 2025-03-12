// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Supervised, URIMalleableSupervised} from "./Supervised.sol";
import {Nft} from "../libs/Nft.sol";

/**
 * Allows changing of the NFT's URI (by the URI_DATA_ROLE), where the URI
 * should e.g. redirect permanently (301) to a corresponding IPFS address.
 * A URI for a particular year becomes permanent after a decade, but only
 * if set (i.e. non-empty) before *or* after the cut-off year.
 *
 * Further, specifies a contract-level metadata URI to support Opensea.io,
 * including a setter (guarded by the same URI_DATA_ROLE).
 */
abstract contract URIMalleable is ERC1155, URIMalleableSupervised {
    /** metadata URI: year-of(nft-id) => value */
    mapping(uint256 => string) private _uris;
    /** metadata URI: malleability duration */
    uint256 private constant DECADE = 10;
    /** metadata URI: contract-level */
    string private _uriContract;

    /** get contract-level metadata URI */
    function contractURI() external view returns (string memory) {
        return _uriContract;
    }

    /** set contract-level metadata URI */
    function setContractURI(
        string memory newuri
    ) external onlyRole(URI_DATA_ROLE) {
        _uriContract = newuri;
    }

    /** set default metadata URI */
    function setURI(string memory newuri) external onlyRole(URI_DATA_ROLE) {
        _setURI(newuri);
    }

    /** set metadata URI (for year) */
    function setURI(
        string memory newuri,
        uint256 year
    ) external onlyRole(URI_DATA_ROLE) {
        if (!_empty(_uris[year])) {
            require(year + DECADE > Nft.year(), "immalleable year");
        }
        require(year > 2020, "invalid year");
        _uris[year] = newuri;
    }

    /** @return URI of nft-id */
    function uri(
        uint256 nftId
    ) public view virtual override returns (string memory) {
        string memory value = _uris[Nft.yearOf(nftId)];
        return !_empty(value) ? value : super.uri(nftId);
    }

    /** @return true if URI of nft-id is permanent */
    function fixedURI(uint256 nftId) external view returns (bool) {
        uint256 year = Nft.yearOf(nftId);
        if (_empty(_uris[year])) {
            return false;
        }
        if (year + DECADE > Nft.year()) {
            return false;
        }
        return true;
    }

    function _empty(string memory value) private pure returns (bool) {
        return bytes(value).length == 0;
    }

    /** @return true if this contract implements the interface defined by interface-id */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, Supervised) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
