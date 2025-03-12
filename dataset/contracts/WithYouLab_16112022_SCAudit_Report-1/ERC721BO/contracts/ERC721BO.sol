// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./IERC721BO.sol";
import "./Bits.sol";
import "./Assets.sol";
import "./Owners.sol";
import "./Counter.sol";

abstract contract ERC721BO is Context, IERC721BO {
    using Address for address;
    using Strings for uint256;
    using Bits for uint256;
    using Assets for Assets.Pages;
    using Owners for Owners.AddressSet;
    using Counter for Counter.Minted;

    uint256 private constant DEFAULT_MAX_TOKEN_COUNT = 1 << 16;

    //Burned tokens are stored as assets at address(1).
    address private constant BURN_ADDRESS = address(1);

    /**
     * @dev Token name.
     */
    string internal _name;

    /**
     * @dev Token symbol.
     */
    string internal _symbol;

    /**
     * @dev Total minted tokens count.
     * This counter is incremented on each token minting.
     * It is used to generate new token ids.
     * Initialized with `type(uint256).max` to reduce gas cost for first `SSTORE`.
     */
    Counter.Minted private _totalMints;

    /**
     * @dev Used to store token owners.
     * Store multiple owners in bulk with a lazy initialization mechanism.
     */
    Owners.AddressSet private _owners;

    /**
     * @dev Stores the ownership flag table for each owner.
     * `uint256` as one page, 256 ownerships can be stored on a single page.
     */
    Assets.Pages private _assets;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _totalMints.initialize();
    }

    /**
     * @dev Returns true if this contract implements the interface defined by `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165 to learn more about how these ids are created.
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165) returns (bool) {
        return
        interfaceId == type(IERC165).interfaceId ||
        interfaceId == type(IERC721).interfaceId ||
        interfaceId == type(IERC721Enumerable).interfaceId ||
        interfaceId == type(IERC721Metadata).interfaceId;
    }

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        if (owner <= BURN_ADDRESS) revert InvalidAddress();
        return _balanceOf(owner);
    }

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        if (_totalMints.current() <= tokenId) revert NonexistentToken();
        address owner = _owners.ownerOf(tokenId);
        if (owner <= BURN_ADDRESS) revert NonexistentToken();
        return owner;
    }

    /**
     * @dev Returns the token collection name.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert NonexistentToken();
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing tokenURI. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an `Approval` event of ERC721.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721BO.ownerOf(tokenId);
        if (to == owner)
            revert CallerIsNotOwnerNorApproved();

        if (_msgSender() != owner && !isApprovedForAll(owner, _msgSender()))
            revert CallerIsNotOwnerNorApprovedForAll();

        _approve(owner, to, tokenId);
    }

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        if (!_exists(tokenId)) revert NonexistentToken();
        return _tokenApprovals[tokenId];
    }

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call transferFrom or safeTransferFrom for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an `ApprovalForAll` event of ERC721.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See setApprovalForAll
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use safeTransferFrom whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either approve or setApprovalForAll.
     *
     * Emits an `Transfer` event of ERC721.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) revert CallerIsNotOwnerNorApproved();
        _transfer(from, to, tokenId);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either approve or setApprovalForAll.
     * - If `to` refers to a smart contract, it must implement IERC721Receiver.onERC721Received, which is called upon a safe transfer.
     *
     * Emits an `Transfer` event of ERC721.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either approve or setApprovalForAll.
     * - If `to` refers to a smart contract, it must implement IERC721Receiver.onERC721Received, which is called upon a safe transfer.
     *
     * Emits an `Transfer` event of ERC721.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) revert CallerIsNotOwnerNorApproved();
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() public override view returns (uint256){
        return totalMinted() - totalBurnt();
    }

    /**
     * @dev Returns the total amount of burnt token by the contract.
     */
    function totalBurnt() public virtual view returns (uint256){
        return _balanceOf(BURN_ADDRESS);
    }

    /**
     * @dev Returns the total amount of minted token by the contract.
     */
    function totalMinted() public virtual view returns (uint256){
        return _totalMints.current();
    }

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with balanceOf to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public virtual override view returns (uint256){
        uint256 pageCount = _totalMints.current() >> 8;
        uint256 total = 0;

        uint256 i = 0;
        do {
            unchecked {
                uint256 page = _assets.page(owner, i);
                if (page == 0)
                {
                    ++i;
                    continue;
                }

                uint256 count = page.popCount();
                if (total + count > index)
                    return page.indexOf(index - total) + (i << 8);

                total += count;
                ++i;
            }
        } while (i <= pageCount);

        revert IndexOutOfRange();
    }

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with totalSupply to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) public virtual override view returns (uint256){
        uint256 totalMints = _totalMints.current();
        uint256 pageCount = totalMints >> 8;

        uint256 i = 0;
        uint256 popTotal = 0;
        uint256 tokenId = type(uint256).max;

        do {
            unchecked {
                uint256 page = ~_assets.page(BURN_ADDRESS, i);
                if (page == 0)
                {
                    ++i;
                    continue;
                }

                uint256 count = page.popCount();
                if (popTotal + count > index)
                {
                    tokenId = page.indexOf(index - popTotal) + (i << 8);
                    break;
                }

                popTotal += count;
                ++i;
            }
        } while (i <= pageCount);

        if (tokenId >= totalMints)
            revert IndexOutOfRange();

        return tokenId;
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to safeTransferFrom, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement IERC721Receiver.onERC721Received, which is called upon a safe transfer.
     *
     * Emits an `Transfer` event of ERC721.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        if (!_checkOnERC721Received(from, to, tokenId, _data)) revert TransferToNonERC721ReceiverImplementer();
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via approve or setApprovalForAll.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _totalMints.current() > tokenId && !_assets.exists(BURN_ADDRESS, tokenId);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        if (!_exists(tokenId)) revert NonexistentToken();
        if (_assets.exists(spender, tokenId))
            return true;

        address owner = ERC721BO.ownerOf(tokenId);

        // Direct reference to `_tokenApprovals` as it passes `_exists(tokenId)`.
        return (isApprovedForAll(owner, spender) || _tokenApprovals[tokenId] == spender);
    }

    function _safeMint(address to, uint256 quantity) internal virtual {
        _safeMint(to, quantity, "");
    }

    /**
     * @dev Same as `_safeMint`, with an additional `data` parameter which is
     * forwarded in IERC721Receiver.onERC721Received to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 quantity,
        bytes memory _data
    ) internal virtual {
        uint256 start = _totalMints.current();
        _mint(to, start, quantity);

        if (!to.isContract())
            return;

        // Implemented with reference to ERC721A
        // The possibility of overflow is unrealistic based on the `start + quantity` validation in `_mint`.
        unchecked {
            uint256 end = start + quantity;
            uint256 index = start;
            do {
                if (!_checkOnERC721Received(address(0), to, index, _data))
                    revert TransferToNonERC721ReceiverImplementer();
                ++index;
            } while (index <= end);
            // Reentrancy protection.
            if (start + quantity != end) revert();
        }
    }


    /**
     * @dev Safely re-mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement IERC721Receiver.onERC721Received, which is called upon a safe transfer.
     *
     * Emits an `Transfer` event of ERC721.
     */
    function _safeReMint(address to, uint256 tokenId) internal virtual {
        _safeReMint(to, tokenId, "");
    }

    /**
     * @dev Same as `_safeReMint`, with an additional `data` parameter which is
     * forwarded in IERC721Receiver.onERC721Received to contract recipients.
     */
    function _safeReMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _remint(to, tokenId);
        if (!_checkOnERC721Received(address(0), to, tokenId, _data))
            revert TransferToNonERC721ReceiverImplementer();
    }

    /**
     * @dev Batch mints `count` tokens and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use _safeMint whenever possible
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `quantity` mints count.
     *
      * Emits an `Transfer` event of ERC721.
     */
    function _mint(address to, uint256 quantity) internal virtual {
        uint256 start = _totalMints.current();
        _mint(to, start, quantity);
    }

    /**
     * @dev Batch mints `start` to `count` tokens and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use _safeMint whenever possible
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `start` number to start mints.
     * - `quantity` mints count.
     *
     * Emits an `Transfer` event of ERC721.
     */
    function _mint(address to, uint256 start, uint256 quantity) internal virtual {
        if (to <= BURN_ADDRESS)
            revert InvalidAddress();

        // Cannot mint more than a defined number of mints
        if (start + quantity > _getMaxTokenCount())
            revert ExceededMaxOfMint();

        _beforeTokenMint(address(0), to, start, quantity);

        _assets.setRange(to, start, quantity);
        _owners.mint(to, start, quantity);
        _totalMints.increment(quantity);

        // Unchecked as it is emit only.
        unchecked {
            uint256 i = 0;
            do {
                emit Transfer(address(0), to, start + i);
                ++i;
            } while (i < quantity);
        }

        _afterTokenMint(address(0), to, start, quantity);
    }

    /**
     * @dev Re-mints `tokenId` and transfers it to `to`.
     * The approval is cleared when the token is burned.
     *
     * WARNING: Usage of this method is discouraged, use _safeReMint whenever possible
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` must not exist and burnt.
     *
     * Emits an `Transfer` event of ERC721.
     */
    function _remint(address to, uint256 tokenId) internal virtual {
        if (to <= BURN_ADDRESS)
            revert InvalidAddress();

        // Burned tokens become the property of `BURN_ADDRESS`.
        if (!_assets.exists(BURN_ADDRESS, tokenId))
            revert TokenAlreadyMinted();

        _beforeTokenTransfer(address(0), to, tokenId);

        _assets.transfer(BURN_ADDRESS, to, tokenId);
        _owners.overwrite(tokenId, to);

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits an `Transfer` event of ERC721.
     */
    function _burn(uint256 tokenId) internal virtual {
        if(!_exists(tokenId))
            revert NonexistentToken();

        address owner = ERC721BO.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _clearApprove(owner, tokenId);

        //  Burned tokens are stored in the `BURN_ADDRESS` asset.
        _assets.transfer(owner, BURN_ADDRESS, tokenId);
        _owners.overwrite(tokenId, BURN_ADDRESS);

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to transferFrom, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits an `Transfer` event of ERC721.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        if (!_assets.exists(from, tokenId))
            revert TransferFromIncorrectOwner();

        if (to <= BURN_ADDRESS)
            revert InvalidAddress();

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _clearApprove(from, tokenId);

        _assets.transfer(from, to, tokenId);
        _owners.overwrite(tokenId, to);

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approval for `tokenId` from `from` to zero address.
     *
     * Emits an `Approval` event of ERC721.
     */
    function _clearApprove(address from, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = address(0);
        emit Approval(from, address(0), tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId` of `owner`
     *
     * Emits an `Approval` event of ERC721.
     */
    function _approve(address owner, address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an `ApprovalForAll` event of ERC721.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        if (owner == operator) revert ApproveToCaller();
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Returns the number of tokens in the `owner`'s account.
     * Note that no validation of the specified address is performed.
     */
    function _balanceOf(address owner) internal view returns (uint256) {
        uint256 pageCount = _totalMints.current() >> 8;
        uint256 balance = 0;

        // Counting Owner Flags.
        // The number of pages is calculated from the total mints.
        // Therefore, the max value of `balance` is `page count * 256` and it is impractical to overflow.
        unchecked {
            uint256 i = 0;
            do {
                balance += _assets.page(owner, i).popCount();
                ++i;
            } while (i <= pageCount);
        }
        return balance;
    }


    /**
     * @dev Returns the maximum of tokens that can be stored by the contract.
     */
    function _getMaxTokenCount() internal pure returns (uint256) {
        return DEFAULT_MAX_TOKEN_COUNT;
    }

    /**
     * @dev Internal function to invoke IERC721Receiver.onERC721Received on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert TransferToNonERC721ReceiverImplementer();
                } else {
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
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    function _beforeTokenMint(
        address from,
        address to,
        uint256 start,
        uint256 quantity
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    function _afterTokenMint(
        address from,
        address to,
        uint256 start,
        uint256 quantity
    ) internal virtual {}
}
