// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../nERC721/IERC721Lockers.sol";
import "../nNFT.sol";
import "./INiimferNFT.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Pausable, nERC721Enumerable, Burnable
contract NiimferNFT is nNFT, INiimferNFT, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address;

    address public officialAccount;
    // Total burned niimfers
    uint256 private _totalBurned;

    mapping(uint256 => NiimferInfo) private idToNiimferInfo; // mapping niimfer tokenId to NiimferInfo
    mapping(uint256 => uint256[]) private niimferTags;
    mapping(uint256 => uint256) private niimferEvent;
    // Mapping from token ID to locker address
    mapping(uint256 => address) private _lockedBy;

    // Address of NiimferStatus
    address private _niimferStats;

    constructor() nNFT("https://api.niimferworld.com/", "Niimfer World NFT", "NIIMFER") {
        officialAccount = msg.sender;
    }

    /* ========== EVENTS ========== */
    event OnNiimferCreated(uint256 indexed itemId, address marketContract);

    event OnBurnNiimfer(uint256 totalBurned, uint256 tokenId);

    /* ========== VIEW FUNCTIONS ========== */

    /**
     * @dev Returns the total burned `niimfers`.
     */
    function totalBurned() external view override returns (uint256) {
        return _totalBurned;
    }

    function exists(uint256 tokenId) external view virtual override returns (bool) {
        return _exists(tokenId);
    }

    function lockedBy(uint256 tokenId) external view override returns (address) {
        return _lockedBy[tokenId];
    }

    /**
     * @dev get niimfer info
     */
    function getNiimferInfo(uint256 tokenId) external view returns (NiimferInfo memory) {
        NiimferInfo storage niimferInfo = idToNiimferInfo[tokenId];
        return niimferInfo;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function setOfficialAccount(address _account) external onlyAdmin {
        require(_account != address(0), "zero");
        officialAccount = _account;
        emit OnUpdateOfficialAccount(_account);
    }

    function setNiimferStats(address newNiimferStats) external onlyManagers {
        require(newNiimferStats != address(0));
        _niimferStats = newNiimferStats;
    }

    function addTagToNiimfer(
        uint256 tokenId,
        uint256 sales_version,
        uint16 eventId,
        uint16 rareId
    ) external override onlyManagers {
        idToNiimferInfo[tokenId] = NiimferInfo(sales_version, eventId, rareId);
        emit OnAddTagToNiimfer(tokenId, sales_version, eventId, rareId);
    }

    /**
     *  @dev
     * Emits a {OnNiimferCreated} event.
     */
    function _createToken(uint256 tokenId, address marketContract) internal onlyMinter {
        _safeMint(msg.sender, tokenId);
        setApprovalForAll(marketContract, true);
        emit OnNiimferCreated(tokenId, marketContract);
    }

    function batchCreateToken(
        uint256 start_tokenId,
        uint256 end_tokenId,
        address marketContract
    ) external virtual {
        for (uint256 i = start_tokenId; i <= end_tokenId; i++) {
            _createToken(i, marketContract);
        }
    }

    function lock(uint256 tokenId, address locker) external override nonReentrant {
        require(_lockedBy[tokenId] == address(0), "locked");
        require(_isApprovedOrOwner(_msgSender(), tokenId), "transfer caller =! owner nor approved");
        _lockedBy[tokenId] = locker;
        require(_checkOnERC721Locked(ownerOf(tokenId), locker, tokenId, ""), "lock failed");
    }

    function unlock(uint256 tokenId) external override {
        require(_exists(tokenId), "!token");
        require(_lockedBy[tokenId] == _msgSender() || isManager(_msgSender()), "caller !=role");
        require(_checkOnERC721Unlocked(ownerOf(tokenId), _lockedBy[tokenId], tokenId, ""), "unlock failed");
        delete _lockedBy[tokenId];
    }

    /**
     * @dev Internal function to invoke {IERC721Locker-onERC721Locked} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the owner of the given token ID
     * @param locker target address that will lock the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Locked(
        address from,
        address locker,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (locker.isContract()) {
            try IERC721Locker(locker).onERC721Locked(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Locker(locker).onERC721Locked.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("lock by non ERC721Locker");
                } else {
                    // solhint-disable-next-line no-inline-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Internal function to invoke {IERC721Locker-onERC721Unlocked} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the owner of the given token ID
     * @param locker target address that will lock the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Unlocked(
        address from,
        address locker,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (locker.isContract()) {
            try IERC721Locker(locker).onERC721Unlocked(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Locker(locker).onERC721Unlocked.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("unlock from a non ERC721Locker implementer");
                } else {
                    // solhint-disable-next-line no-inline-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Burns `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     * Emits a {OnNiimferCreated} event.
     */
    function burn(uint256 tokenId) public virtual override nonReentrant {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "caller !=approved");
        _burn(tokenId);
        _totalBurned++;
        emit OnBurnNiimfer(_totalBurned, tokenId);
    }

    /**
     * @dev See {ERC721-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the token is not locked or the target (to) is the locker
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (_lockedBy[tokenId] != to) {
            require(_lockedBy[tokenId] == address(0), "token locked");
        } else {
            delete _lockedBy[tokenId];
        }
    }

    /* ========== EMERGENCY ========== */

    function withdrawERC20Token(address _token) external onlyAdmin {
        IERC20(_token).transfer(officialAccount, IERC20(_token).balanceOf(address(this)));
    }
}
