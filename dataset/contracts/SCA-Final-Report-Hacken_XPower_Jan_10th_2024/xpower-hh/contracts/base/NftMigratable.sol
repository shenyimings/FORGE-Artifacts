// SPDX-License-Identifier: GPL-3.0
// solhint-disable not-rely-on-time
pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Burnable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

import {Nft} from "../libs/Nft.sol";
import {Supervised, NftMigratableSupervised} from "./Supervised.sol";

/**
 * Allows migration of NFTs from an old contract; batch migration is also
 * possible. Further, manually sealing the migration is possible too.
 */
abstract contract NftMigratable is ERC1155, ERC1155Burnable, NftMigratableSupervised {
    /** burnable ERC1155 tokens */
    ERC1155Burnable[] private _base;
    /** base address to index map */
    mapping(address => uint256) private _index;
    /** timestamp of immigration deadline */
    uint256 private _deadlineBy;
    /** flag to seal immigration */
    bool[] private _sealed;
    /** flag to open emigration */
    uint256 private _migratable;

    /** @param base addresses of old contracts */
    /** @param deadlineIn seconds to end-of-migration */
    constructor(address[] memory base, uint256 deadlineIn) {
        _deadlineBy = block.timestamp + deadlineIn;
        _base = new ERC1155Burnable[](base.length);
        _sealed = new bool[](base.length);
        for (uint256 i = 0; i < base.length; i++) {
            _base[i] = ERC1155Burnable(base[i]);
            _index[base[i]] = i;
        }
    }

    /** @return index of base address */
    function oldIndexOf(address base) external view returns (uint256) {
        return _index[base];
    }

    /** migrate amount of ERC1155 */
    function migrate(uint256 nftId, uint256 amount, uint256[] memory index) external {
        _migrateFrom(msg.sender, nftId, amount, index);
    }

    /** migrate amount of ERC1155 */
    function migrateFrom(address account, uint256 nftId, uint256 amount, uint256[] memory index) external {
        _migrateFrom(account, nftId, amount, index);
    }

    /** migrate amount of ERC1155 */
    function _migrateFrom(address account, uint256 nftId, uint256 amount, uint256[] memory index) internal {
        require(_deadlineBy >= block.timestamp, "deadline passed");
        _burnFrom(account, nftId, amount, index);
        _mint(account, nftId, amount, "");
    }

    /** burn amount of ERC1155 */
    function _burnFrom(address account, uint256 nftId, uint256 amount, uint256[] memory index) internal virtual {
        require(!_sealed[index[0]], "migration sealed");
        uint256 tryId = nftId + Nft.eonOf(Nft.yearOf(nftId)) * 2;
        uint256 tryBalance = _base[index[0]].balanceOf(account, tryId);
        _base[index[0]].burn(account, tryBalance > 0 ? tryId : nftId, amount);
    }

    /** batch-migrate amounts of ERC1155 */
    function migrateBatch(uint256[] memory nftIds, uint256[] memory amounts, uint256[] memory index) external {
        _migrateFromBatch(msg.sender, nftIds, amounts, index);
    }

    /** batch-migrate amounts of ERC1155 */
    function migrateFromBatch(
        address account,
        uint256[] memory nftIds,
        uint256[] memory amounts,
        uint256[] memory index
    ) external {
        _migrateFromBatch(account, nftIds, amounts, index);
    }

    /** batch-migrate amounts of ERC1155 */
    function _migrateFromBatch(
        address account,
        uint256[] memory nftIds,
        uint256[] memory amounts,
        uint256[] memory index
    ) internal {
        require(_deadlineBy >= block.timestamp, "deadline passed");
        for (uint256 i = 0; i < nftIds.length; i++) {
            _burnFrom(account, nftIds[i], amounts[i], index);
        }
        _mintBatch(account, nftIds, amounts, "");
    }

    /** seal immigration */
    function seal(uint256 index) external onlyRole(NFT_SEAL_ROLE) {
        _sealed[index] = true;
    }

    /** seal-all immigration */
    function sealAll() external onlyRole(NFT_SEAL_ROLE) {
        for (uint256 i = 0; i < _sealed.length; i++) {
            _sealed[i] = true;
        }
    }

    /** @return seal flags (of all bases) */
    function seals() external view returns (bool[] memory) {
        return _sealed;
    }

    /** emitted on opening emigration */
    event Migratable(uint256 timestamp);

    /** open emigration for *all* nft-years (deferred by a week) */
    function migratable(bool flag) external onlyRole(NFT_OPEN_ROLE) {
        if (flag && _migratable == 0) {
            _migratable = block.timestamp + 7 days;
            emit Migratable(_migratable);
        }
    }

    /** @return emigration flag */
    function migratable() public view returns (bool) {
        if (_migratable > 0) {
            return block.timestamp >= _migratable;
        }
        return false;
    }

    /** @return true if this contract implements the interface defined by interface-id */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, Supervised) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
