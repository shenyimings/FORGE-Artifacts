// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import {IERC721} from "./IERC721.sol";
import {IERC721Receiver} from "./IERC721Receiver.sol";
import {IERC721Metadata} from "./IERC721Metadata.sol";
import {IERC721BatchTransfer} from "./IERC721BatchTransfer.sol";
import {IERC165} from "@animoca/ethereum-contracts-core-1.1.1/contracts/introspection/IERC165.sol";
import {ManagedIdentity} from "@animoca/ethereum-contracts-core-1.1.1/contracts/metatx/ManagedIdentity.sol";
import {AddressIsContract} from "@animoca/ethereum-contracts-core-1.1.1/contracts/utils/types/AddressIsContract.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
abstract contract ERC721 is ManagedIdentity, IERC165, IERC721, IERC721Metadata, IERC721BatchTransfer {
    using AddressIsContract for address;

    bytes4 internal constant _ERC721_RECEIVED = type(IERC721Receiver).interfaceId;

    uint256 internal constant _APPROVAL_BIT_TOKEN_OWNER_ = 1 << 160;

    // Burnt non-fungible token owner's magic value
    uint256 internal constant _BURNT_NFT_OWNER = 0xdead000000000000000000000000000000000000000000000000000000000000;

    string internal _name;
    string internal _symbol;

    /* owner => operator => approved */
    mapping(address => mapping(address => bool)) internal _operators;

    /* NFT ID => owner */
    mapping(uint256 => uint256) internal _owners;

    /* owner => NFT balance */
    mapping(address => uint256) internal _nftBalances;

    /* NFT ID => operator */
    mapping(uint256 => address) internal _nftApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    //================================== ERC165 =======================================/

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC721BatchTransfer).interfaceId;
    }

    //================================== ERC721Metadata =======================================/

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    //================================== ERC721 =======================================/

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: zero address");
        return _nftBalances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = address(uint160(_owners[tokenId]));
        require(owner != address(0), "ERC721: non-existing NFT");
        return owner;
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address tokenOwner = ownerOf(tokenId);
        require(to != tokenOwner, "ERC721: self-approval");
        require(_isOperatable(tokenOwner, _msgSender()), "ERC721: non-approved sender");
        _owners[tokenId] = uint256(uint160(tokenOwner)) | _APPROVAL_BIT_TOKEN_OWNER_;
        _nftApprovals[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        uint256 tokenOwner = _owners[tokenId];
        require(address(uint160(tokenOwner)) != address(0), "ERC721: non-existing NFT");
        if (tokenOwner & _APPROVAL_BIT_TOKEN_OWNER_ != 0) {
            return _nftApprovals[tokenId];
        } else {
            return address(0);
        }
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        address sender = _msgSender();
        require(operator != sender, "ERC721: self-approval");
        _operators[sender][operator] = approved;
        emit ApprovalForAll(sender, operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operators[owner][operator];
    }

    /**
     * Unsafely transfers a Non-Fungible Token (ERC721-compatible).
     * @dev See {IERC721-transferFrom(address,address,uint256)}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        _transferFrom(
            from,
            to,
            tokenId,
            "",
            /* safe */
            false
        );
    }

    /**
     * Safely transfers a Non-Fungible Token (ERC721-compatible).
     * @dev See {IERC721-safeTransferFrom(address,address,uint256)}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        _transferFrom(
            from,
            to,
            tokenId,
            "",
            /* safe */
            true
        );
    }

    /**
     * Safely transfers a Non-Fungible Token (ERC721-compatible).
     * @dev See {IERC721-safeTransferFrom(address,address,uint256,bytes)}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        _transferFrom(
            from,
            to,
            tokenId,
            data,
            /* safe */
            true
        );
    }

    /**
     * Unsafely transfers a batch of Non-Fungible Tokens (ERC721-compatible).
     * @dev See {IERC721BatchTransfer-batchTransferFrom(address,address,uint256[])}.
     */
    function batchTransferFrom(
        address from,
        address to,
        uint256[] memory tokenIds
    ) public virtual override {
        require(to != address(0), "ERC721: transfer to zero");
        address sender = _msgSender();
        bool operatable = _isOperatable(from, sender);

        uint256 length = tokenIds.length;

        for (uint256 i; i != length; ++i) {
            uint256 tokenId = tokenIds[i];
            _transferNFT(from, to, tokenId, operatable, true);
            emit Transfer(from, to, tokenId);
        }

        if (length != 0) {
            _transferNFTUpdateBalances(from, to, length);
        }
    }

    /**
     * Safely or unsafely mints some token (ERC721-compatible).
     * @dev For `safe` mint, see {IERC721Mintable-mint(address,uint256)}.
     * @dev For un`safe` mint, see {IERC721Mintable-safeMint(address,uint256,bytes)}.
     */
    function _mint(
        address to,
        uint256 tokenId,
        bytes memory data,
        bool safe
    ) internal {
        require(to != address(0), "ERC721: mint to zero");

        _mintNFT(to, tokenId, false);

        emit Transfer(address(0), to, tokenId);
        if (safe && to.isContract()) {
            _callOnERC721Received(address(0), to, tokenId, data);
        }
    }

    /**
     * Unsafely mints a batch of Non-Fungible Tokens (ERC721-compatible).
     * @dev See {IERC721Mintable-batchMint(address,uint256[])}.
     */
    function _batchMint(address to, uint256[] memory tokenIds) internal {
        require(to != address(0), "ERC721: mint to zero");

        uint256 length = tokenIds.length;
        uint256[] memory values = new uint256[](length);

        for (uint256 i; i != length; ++i) {
            uint256 tokenId = tokenIds[i];
            values[i] = 1;
            _mintNFT(to, tokenId, true);
            emit Transfer(address(0), to, tokenId);
        }

        _nftBalances[to] += length;
    }

    /**
     * Safely or unsafely transfers some token.
     * @dev For `safe` transfer, see {IERC721-transferFrom(address,address,uint256)}.
     * @dev For un`safe` transfer, see {IERC721-safeTransferFrom(address,address,uint256,bytes)}.
     */
    function _transferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data,
        bool safe
    ) internal {
        require(to != address(0), "ERC721: transfer to zero");
        address sender = _msgSender();
        bool operatable = _isOperatable(from, sender);

        _transferNFT(from, to, tokenId, operatable, false);

        emit Transfer(from, to, tokenId);
        if (safe && to.isContract()) {
            _callOnERC721Received(from, to, tokenId, data);
        }
    }

    function _transferNFT(
        address from,
        address to,
        uint256 id,
        bool operatable,
        bool isBatch
    ) internal virtual {
        uint256 owner = _owners[id];
        require(from == address(uint160(owner)), "ERC721: non-owned NFT");
        if (!operatable) {
            require((owner & _APPROVAL_BIT_TOKEN_OWNER_ != 0) && _msgSender() == _nftApprovals[id], "ERC721: non-approved sender");
        }
        _owners[id] = uint256(uint160(to));
        if (!isBatch) {
            _transferNFTUpdateBalances(from, to, 1);
        }
    }

    function _transferNFTUpdateBalances(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        if (from != to) {
            // cannot underflow as balance is verified through ownership
            _nftBalances[from] -= amount;
            //  cannot overflow as supply cannot overflow
            _nftBalances[to] += amount;
        }
    }

    function _mintNFT(
        address to,
        uint256 id,
        bool isBatch
    ) internal {
        require(_owners[id] == 0, "ERC721: existing/burnt NFT");

        _owners[id] = uint256(uint160(to));

        if (!isBatch) {
            // overflows due to the cost of minting individual tokens
            ++_nftBalances[to];
        }
    }

    /**
     * Calls {IERC721Receiver-onERC721Received} on a target contract.
     * @dev Reverts if `to` is not a contract.
     * @dev Reverts if the call to the target fails or is refused.
     * @param from Previous token owner.
     * @param to New token owner.
     * @param tokenId Identifier of the token transferred.
     * @param data Optional data to send along with the receiver contract call.
     */
    function _callOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal {
        require(IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) == _ERC721_RECEIVED, "ERC721: transfer refused");
    }

    /**
     * Returns whether `sender` is authorised to make a transfer on behalf of `from`.
     * @param from The address to check operatibility upon.
     * @param sender The sender address.
     * @return True if sender is `from` or an operator for `from`, false otherwise.
     */
    function _isOperatable(address from, address sender) internal view virtual returns (bool) {
        return (from == sender) || _operators[from][sender];
    }
}
