// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// solhint-disable-next-line max-line-length
import {ERC721SelfApproval, ERC721SelfApprovalForAll, ERC721NonApprovedForApproval, ERC721TransferToAddressZero, ERC721NonExistingToken, ERC721NonApprovedForTransfer, ERC721NonOwnedToken, ERC721SafeTransferRejected, ERC721BalanceOfAddressZero} from "./../errors/ERC721Errors.sol";
import {ERC721MintToAddressZero, ERC721ExistingToken} from "./../errors/ERC721MintableErrors.sol";
import {ERC721BurntToken} from "./../errors/ERC721MintableOnceErrors.sol";
import {InconsistentArrayLengths} from "./../../../CommonErrors.sol";
import {IERC721Events} from "./../events/IERC721Events.sol";
import {IERC721} from "./../interfaces/IERC721.sol";
import {IERC721BatchTransfer} from "./../interfaces/IERC721BatchTransfer.sol";
import {IERC721Metadata} from "./../interfaces/IERC721Metadata.sol";
import {IERC721Mintable} from "./../interfaces/IERC721Mintable.sol";
import {IERC721Deliverable} from "./../interfaces/IERC721Deliverable.sol";
import {IERC721Burnable} from "./../interfaces/IERC721Burnable.sol";
import {IERC721Receiver} from "./../interfaces/IERC721Receiver.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {InterfaceDetectionStorage} from "./../../../introspection/libraries/InterfaceDetectionStorage.sol";

library ERC721Storage {
    using Address for address;
    using ERC721Storage for ERC721Storage.Layout;
    using InterfaceDetectionStorage for InterfaceDetectionStorage.Layout;

    struct Layout {
        mapping(uint256 => uint256) owners;
        mapping(address => uint256) balances;
        mapping(uint256 => address) approvals;
        mapping(address => mapping(address => bool)) operators;
    }

    bytes32 internal constant LAYOUT_STORAGE_SLOT = bytes32(uint256(keccak256("animoca.token.ERC721.ERC721.storage")) - 1);

    bytes4 internal constant ERC721_RECEIVED = IERC721Receiver.onERC721Received.selector;

    // Single token approval flag
    // This bit is set in the owner's value to indicate that there is an approval set for this token
    uint256 internal constant TOKEN_APPROVAL_OWNER_FLAG = 1 << 160;

    // Burnt token magic value
    // This magic number is used as the owner's value to indicate that the token has been burnt
    uint256 internal constant BURNT_TOKEN_OWNER_VALUE = 0xdead000000000000000000000000000000000000000000000000000000000000;

    /// @notice Marks the following ERC165 interface(s) as supported: ERC721.
    function init() internal {
        InterfaceDetectionStorage.layout().setSupportedInterface(type(IERC721).interfaceId, true);
    }

    /// @notice Marks the following ERC165 interface(s) as supported: ERC721BatchTransfer.
    function initERC721BatchTransfer() internal {
        InterfaceDetectionStorage.layout().setSupportedInterface(type(IERC721BatchTransfer).interfaceId, true);
    }

    /// @notice Marks the following ERC165 interface(s) as supported: ERC721Metadata.
    function initERC721Metadata() internal {
        InterfaceDetectionStorage.layout().setSupportedInterface(type(IERC721Metadata).interfaceId, true);
    }

    /// @notice Marks the following ERC165 interface(s) as supported: ERC721Mintable.
    function initERC721Mintable() internal {
        InterfaceDetectionStorage.layout().setSupportedInterface(type(IERC721Mintable).interfaceId, true);
    }

    /// @notice Marks the following ERC165 interface(s) as supported: ERC721Deliverable.
    function initERC721Deliverable() internal {
        InterfaceDetectionStorage.layout().setSupportedInterface(type(IERC721Deliverable).interfaceId, true);
    }

    /// @notice Marks the following ERC165 interface(s) as supported: ERC721Burnable.
    function initERC721Burnable() internal {
        InterfaceDetectionStorage.layout().setSupportedInterface(type(IERC721Burnable).interfaceId, true);
    }

    /// @notice Sets or unsets an approval to transfer a single token on behalf of its owner.
    /// @dev Note: This function implements {ERC721-approve(address,uint256)}.
    /// @dev Reverts with {ERC721NonExistingToken} if `tokenId` does not exist.
    /// @dev Reverts with {ERC721SelfApproval} if `to` is the token owner.
    /// @dev Reverts with {ERC721NonApprovedForApproval} if `sender` is not the token owner and has not been approved by the token owner.
    /// @dev Emits an {Approval} event.
    /// @param sender The message sender.
    /// @param to The address to approve, or the zero address to remove any existing approval.
    /// @param tokenId The token identifier to give approval for.
    function approve(Layout storage s, address sender, address to, uint256 tokenId) internal {
        uint256 owner = s.owners[tokenId];
        if (!_tokenExists(owner)) revert ERC721NonExistingToken(tokenId);
        address ownerAddress = _tokenOwner(owner);
        if (to == ownerAddress) revert ERC721SelfApproval(ownerAddress);
        if (!_isOperatable(s, ownerAddress, sender)) revert ERC721NonApprovedForApproval(sender, ownerAddress, tokenId);
        if (to == address(0)) {
            if (_tokenHasApproval(owner)) {
                // remove the approval bit if it is present
                s.owners[tokenId] = uint256(uint160(ownerAddress));
            }
        } else {
            uint256 ownerWithApprovalBit = owner | TOKEN_APPROVAL_OWNER_FLAG;
            if (owner != ownerWithApprovalBit) {
                // add the approval bit if it is not present
                s.owners[tokenId] = ownerWithApprovalBit;
            }
            s.approvals[tokenId] = to;
        }
        emit IERC721Events.Approval(ownerAddress, to, tokenId);
    }

    /// @notice Sets or unsets an approval to transfer all tokens on behalf of their owner.
    /// @dev Note: This function implements {ERC721-setApprovalForAll(address,bool)}.
    /// @dev Reverts with {ERC721SelfApprovalForAll} if `sender` is the same as `operator`.
    /// @dev Emits an {ApprovalForAll} event.
    /// @param sender The message sender.
    /// @param operator The address to approve for all tokens.
    /// @param approved True to set an approval for all tokens, false to unset it.
    function setApprovalForAll(Layout storage s, address sender, address operator, bool approved) internal {
        if (operator == sender) revert ERC721SelfApprovalForAll(sender);
        s.operators[sender][operator] = approved;
        emit IERC721Events.ApprovalForAll(sender, operator, approved);
    }

    /// @notice Unsafely transfers the ownership of a token to a recipient by a sender.
    /// @dev Note: This function implements {ERC721-transferFrom(address,address,uint256)}.
    /// @dev Resets the token approval for `tokenId`.
    /// @dev Reverts with {ERC721TransferToAddressZero} if `to` is the zero address.
    /// @dev Reverts with {ERC721NonExistingToken} if `tokenId` does not exist.
    /// @dev Reverts with {ERC721NonOwnedToken} if `from` is not the owner of `tokenId`.
    /// @dev Reverts with {ERC721NonApprovedForTransfer} if `sender` is not `from` and has not been approved by `from` for `tokenId`.
    /// @dev Emits a {Transfer} event.
    /// @param sender The message sender.
    /// @param from The current token owner.
    /// @param to The recipient of the token transfer.
    /// @param tokenId The identifier of the token to transfer.
    function transferFrom(Layout storage s, address sender, address from, address to, uint256 tokenId) internal {
        if (to == address(0)) revert ERC721TransferToAddressZero();

        uint256 owner = s.owners[tokenId];
        if (!_tokenExists(owner)) revert ERC721NonExistingToken(tokenId);
        if (_tokenOwner(owner) != from) revert ERC721NonOwnedToken(from, tokenId);

        if (!_isOperatable(s, from, sender)) {
            if (!_tokenHasApproval(owner) || sender != s.approvals[tokenId]) revert ERC721NonApprovedForTransfer(sender, from, tokenId);
        }

        s.owners[tokenId] = uint256(uint160(to));
        if (from != to) {
            unchecked {
                // cannot underflow as balance is verified through ownership
                --s.balances[from];
                //  cannot overflow as supply cannot overflow
                ++s.balances[to];
            }
        }

        emit IERC721Events.Transfer(from, to, tokenId);
    }

    /// @notice Safely transfers the ownership of a token to a recipient by a sender.
    /// @dev Note: This function implements {ERC721-safeTransferFrom(address,address,uint256)}.
    /// @dev Warning: Since a `to` contract can run arbitrary code, developers should be aware of potential re-entrancy attacks.
    /// @dev Resets the token approval for `tokenId`.
    /// @dev Reverts with {ERC721TransferToAddressZero} if `to` is the zero address.
    /// @dev Reverts with {ERC721NonExistingToken} if `tokenId` does not exist.
    /// @dev Reverts with {ERC721NonOwnedToken} if `from` is not the owner of `tokenId`.
    /// @dev Reverts with {ERC721NonApprovedForTransfer} if `sender` is not `from` and has not been approved by `from` for `tokenId`.
    /// @dev Reverts with {ERC721SafeTransferRejected} if `to` is a contract and the call to
    ///  {IERC721Receiver-onERC721Received} fails, reverts or is rejected.
    /// @dev Emits a {Transfer} event.
    /// @param sender The message sender.
    /// @param from The current token owner.
    /// @param to The recipient of the token transfer.
    /// @param tokenId The identifier of the token to transfer.
    function safeTransferFrom(Layout storage s, address sender, address from, address to, uint256 tokenId) internal {
        s.transferFrom(sender, from, to, tokenId);
        if (to.isContract()) {
            _callOnERC721Received(sender, from, to, tokenId, "");
        }
    }

    /// @notice Safely transfers the ownership of a token to a recipient by a sender.
    /// @dev Note: This function implements {ERC721-safeTransferFrom(address,address,uint256,bytes)}.
    /// @dev Warning: Since a `to` contract can run arbitrary code, developers should be aware of potential re-entrancy attacks.
    /// @dev Resets the token approval for `tokenId`.
    /// @dev Reverts with {ERC721TransferToAddressZero} if `to` is the zero address.
    /// @dev Reverts with {ERC721NonExistingToken} if `tokenId` does not exist.
    /// @dev Reverts with {ERC721NonOwnedToken} if `from` is not the owner of `tokenId`.
    /// @dev Reverts with {ERC721NonApprovedForTransfer} if `sender` is not `from` and has not been approved by `from` for `tokenId`.
    /// @dev Reverts with {ERC721SafeTransferRejected} if `to` is a contract and the call to
    ///  {IERC721Receiver-onERC721Received} fails, reverts or is rejected.
    /// @dev Emits a {Transfer} event.
    /// @param sender The message sender.
    /// @param from The current token owner.
    /// @param to The recipient of the token transfer.
    /// @param tokenId The identifier of the token to transfer.
    /// @param data Optional data to send along to a receiver contract.
    function safeTransferFrom(Layout storage s, address sender, address from, address to, uint256 tokenId, bytes calldata data) internal {
        s.transferFrom(sender, from, to, tokenId);
        if (to.isContract()) {
            _callOnERC721Received(sender, from, to, tokenId, data);
        }
    }

    /// @notice Unsafely transfers a batch of tokens to a recipient by a sender.
    /// @dev Note: This function implements {ERC721BatchTransfer-batchTransferFrom(address,address,uint256[])}.
    /// @dev Resets the token approval for each of `tokenIds`.
    /// @dev Reverts with {ERC721TransferToAddressZero} if `to` is the zero address.
    /// @dev Reverts with {ERC721NonExistingToken} if one of `tokenIds` does not exist.
    /// @dev Reverts with {ERC721NonOwnedToken} if one of `tokenIds` is not owned by `from`.
    /// @dev Reverts with {ERC721NonApprovedForTransfer} if the sender is not `from` and has not been approved by `from` for each of `tokenIds`.
    /// @dev Emits a {Transfer} event for each of `tokenIds`.
    /// @param sender The message sender.
    /// @param from Current tokens owner.
    /// @param to Address of the new token owner.
    /// @param tokenIds Identifiers of the tokens to transfer.
    function batchTransferFrom(Layout storage s, address sender, address from, address to, uint256[] calldata tokenIds) internal {
        if (to == address(0)) revert ERC721TransferToAddressZero();
        bool operatable = _isOperatable(s, from, sender);

        uint256 length = tokenIds.length;
        unchecked {
            for (uint256 i; i != length; ++i) {
                uint256 tokenId = tokenIds[i];
                uint256 owner = s.owners[tokenId];
                if (!_tokenExists(owner)) revert ERC721NonExistingToken(tokenId);
                if (_tokenOwner(owner) != from) revert ERC721NonOwnedToken(from, tokenId);
                if (!operatable) {
                    if (!_tokenHasApproval(owner) || sender != s.approvals[tokenId]) revert ERC721NonApprovedForTransfer(sender, from, tokenId);
                }
                s.owners[tokenId] = uint256(uint160(to));
                emit IERC721Events.Transfer(from, to, tokenId);
            }

            if (from != to && length != 0) {
                // cannot underflow as balance is verified through ownership
                s.balances[from] -= length;
                // cannot overflow as supply cannot overflow
                s.balances[to] += length;
            }
        }
    }

    /// @notice Unsafely mints a token.
    /// @dev Note: This function implements {ERC721Mintable-mint(address,uint256)}.
    /// @dev Note: Either `mint` or `mintOnce` should be used in a given contract, but not both.
    /// @dev Reverts with {ERC721MintToAddressZero} if `to` is the zero address.
    /// @dev Reverts with {ERC721ExistingToken} if `tokenId` already exists.
    /// @dev Emits a {Transfer} event from the zero address.
    /// @param to Address of the new token owner.
    /// @param tokenId Identifier of the token to mint.
    function mint(Layout storage s, address to, uint256 tokenId) internal {
        if (to == address(0)) revert ERC721MintToAddressZero();
        if (_tokenExists(s.owners[tokenId])) revert ERC721ExistingToken(tokenId);

        s.owners[tokenId] = uint256(uint160(to));

        unchecked {
            // cannot overflow due to the cost of minting individual tokens
            ++s.balances[to];
        }

        emit IERC721Events.Transfer(address(0), to, tokenId);
    }

    /// @notice Safely mints a token.
    /// @dev Note: This function implements {ERC721Mintable-safeMint(address,uint256,bytes)}.
    /// @dev Note: Either `safeMint` or `safeMintOnce` should be used in a given contract, but not both.
    /// @dev Warning: Since a `to` contract can run arbitrary code, developers should be aware of potential re-entrancy attacks.
    /// @dev Reverts with {ERC721MintToAddressZero} if `to` is the zero address.
    /// @dev Reverts with {ERC721ExistingToken} if `tokenId` already exists.
    /// @dev Reverts with {ERC721SafeTransferRejected} if `to` is a contract and the call to
    ///  {IERC721Receiver-onERC721Received} fails, reverts or is rejected.
    /// @dev Emits a {Transfer} event from the zero address.
    /// @param to Address of the new token owner.
    /// @param tokenId Identifier of the token to mint.
    /// @param data Optional data to pass along to the receiver call.
    function safeMint(Layout storage s, address sender, address to, uint256 tokenId, bytes memory data) internal {
        s.mint(to, tokenId);
        if (to.isContract()) {
            _callOnERC721Received(sender, address(0), to, tokenId, data);
        }
    }

    /// @notice Unsafely mints a batch of tokens.
    /// @dev Note: This function implements {ERC721Mintable-batchMint(address,uint256[])}.
    /// @dev Note: Either `batchMint` or `batchMintOnce` should be used in a given contract, but not both.
    /// @dev Reverts with {ERC721MintToAddressZero} if `to` is the zero address.
    /// @dev Reverts with {ERC721ExistingToken} if one of `tokenIds` already exists.
    /// @dev Emits a {Transfer} event from the zero address for each of `tokenIds`.
    /// @param to Address of the new tokens owner.
    /// @param tokenIds Identifiers of the tokens to mint.
    function batchMint(Layout storage s, address to, uint256[] memory tokenIds) internal {
        if (to == address(0)) revert ERC721MintToAddressZero();

        uint256 length = tokenIds.length;
        unchecked {
            for (uint256 i; i != length; ++i) {
                uint256 tokenId = tokenIds[i];
                if (_tokenExists(s.owners[tokenId])) revert ERC721ExistingToken(tokenId);

                s.owners[tokenId] = uint256(uint160(to));
                emit IERC721Events.Transfer(address(0), to, tokenId);
            }

            s.balances[to] += length;
        }
    }

    /// @notice Unsafely mints tokens to multiple recipients.
    /// @dev Note: This function implements {ERC721Deliverable-deliver(address[],uint256[])}.
    /// @dev Note: Either `deliver` or `deliverOnce` should be used in a given contract, but not both.
    /// @dev Reverts with {InconsistentArrayLengths} if `recipients` and `tokenIds` have different lengths.
    /// @dev Reverts with {ERC721MintToAddressZero} if one of `recipients` is the zero address.
    /// @dev Reverts with {ERC721ExistingToken} if one of `tokenIds` already exists.
    /// @dev Emits a {Transfer} event from the zero address for each of `recipients` and `tokenIds`.
    /// @param recipients Addresses of the new tokens owners.
    /// @param tokenIds Identifiers of the tokens to mint.
    function deliver(Layout storage s, address[] memory recipients, uint256[] memory tokenIds) internal {
        uint256 length = recipients.length;
        if (length != tokenIds.length) revert InconsistentArrayLengths();
        unchecked {
            for (uint256 i; i != length; ++i) {
                s.mint(recipients[i], tokenIds[i]);
            }
        }
    }

    /// @notice Unsafely mints a token once.
    /// @dev Note: This function implements {ERC721Mintable-mint(address,uint256)}.
    /// @dev Note: Either `mint` or `mintOnce` should be used in a given contract, but not both.
    /// @dev Reverts with {ERC721MintToAddressZero} if `to` is the zero address.
    /// @dev Reverts with {ERC721ExistingToken} if `tokenId` already exists.
    /// @dev Reverts with {ERC721BurntToken} if `tokenId` has been previously burnt.
    /// @dev Emits a {Transfer} event from the zero address.
    /// @param to Address of the new token owner.
    /// @param tokenId Identifier of the token to mint.
    function mintOnce(Layout storage s, address to, uint256 tokenId) internal {
        if (to == address(0)) revert ERC721MintToAddressZero();

        uint256 owner = s.owners[tokenId];
        if (_tokenExists(owner)) revert ERC721ExistingToken(tokenId);
        if (_tokenWasBurnt(owner)) revert ERC721BurntToken(tokenId);

        s.owners[tokenId] = uint256(uint160(to));

        unchecked {
            // cannot overflow due to the cost of minting individual tokens
            ++s.balances[to];
        }

        emit IERC721Events.Transfer(address(0), to, tokenId);
    }

    /// @notice Safely mints a token once.
    /// @dev Note: This function implements {ERC721Mintable-safeMint(address,uint256,bytes)}.
    /// @dev Note: Either `safeMint` or `safeMintOnce` should be used in a given contract, but not both.
    /// @dev Reverts with {ERC721MintToAddressZero} if `to` is the zero address.
    /// @dev Reverts with {ERC721ExistingToken} if `tokenId` already exists.
    /// @dev Reverts with {ERC721BurntToken} if `tokenId` has been previously burnt.
    /// @dev Reverts with {ERC721SafeTransferRejected} if `to` is a contract and the call to
    ///  {IERC721Receiver-onERC721Received} fails, reverts or is rejected.
    /// @dev Emits a {Transfer} event from the zero address.
    /// @param to Address of the new token owner.
    /// @param tokenId Identifier of the token to mint.
    /// @param data Optional data to pass along to the receiver call.
    function safeMintOnce(Layout storage s, address sender, address to, uint256 tokenId, bytes memory data) internal {
        s.mintOnce(to, tokenId);
        if (to.isContract()) {
            _callOnERC721Received(sender, address(0), to, tokenId, data);
        }
    }

    /// @notice Unsafely mints a batch of tokens once.
    /// @dev Note: This function implements {ERC721Mintable-batchMint(address,uint256[])}.
    /// @dev Note: Either `batchMint` or `batchMintOnce` should be used in a given contract, but not both.
    /// @dev Reverts with {ERC721MintToAddressZero} if `to` is the zero address.
    /// @dev Reverts with {ERC721ExistingToken} if one of `tokenIds` already exists.
    /// @dev Reverts with {ERC721BurntToken} if one of `tokenIds` has been previously burnt.
    /// @dev Emits a {Transfer} event from the zero address for each of `tokenIds`.
    /// @param to Address of the new tokens owner.
    /// @param tokenIds Identifiers of the tokens to mint.
    function batchMintOnce(Layout storage s, address to, uint256[] memory tokenIds) internal {
        if (to == address(0)) revert ERC721MintToAddressZero();

        uint256 length = tokenIds.length;
        unchecked {
            for (uint256 i; i != length; ++i) {
                uint256 tokenId = tokenIds[i];
                uint256 owner = s.owners[tokenId];
                if (_tokenExists(owner)) revert ERC721ExistingToken(tokenId);
                if (_tokenWasBurnt(owner)) revert ERC721BurntToken(tokenId);

                s.owners[tokenId] = uint256(uint160(to));

                emit IERC721Events.Transfer(address(0), to, tokenId);
            }

            s.balances[to] += length;
        }
    }

    /// @notice Unsafely mints tokens to multiple recipients once.
    /// @dev Note: This function implements {ERC721Deliverable-deliver(address[],uint256[])}.
    /// @dev Note: Either `deliver` or `deliverOnce` should be used in a given contract, but not both.
    /// @dev Reverts with {InconsistentArrayLengths} if `recipients` and `tokenIds` have different lengths.
    /// @dev Reverts with {ERC721MintToAddressZero} if one of `recipients` is the zero address.
    /// @dev Reverts with {ERC721ExistingToken} if one of `tokenIds` already exists.
    /// @dev Reverts with {ERC721BurntToken} if one of `tokenIds` has been previously burnt.
    /// @dev Emits a {Transfer} event from the zero address for each of `recipients` and `tokenIds`.
    /// @param recipients Addresses of the new tokens owners.
    /// @param tokenIds Identifiers of the tokens to mint.
    function deliverOnce(Layout storage s, address[] memory recipients, uint256[] memory tokenIds) internal {
        uint256 length = recipients.length;
        if (length != tokenIds.length) revert InconsistentArrayLengths();
        unchecked {
            for (uint256 i; i != length; ++i) {
                address to = recipients[i];
                if (to == address(0)) revert ERC721MintToAddressZero();

                uint256 tokenId = tokenIds[i];
                uint256 owner = s.owners[tokenId];
                if (_tokenExists(owner)) revert ERC721ExistingToken(tokenId);
                if (_tokenWasBurnt(owner)) revert ERC721BurntToken(tokenId);

                s.owners[tokenId] = uint256(uint160(to));
                ++s.balances[to];

                emit IERC721Events.Transfer(address(0), to, tokenId);
            }
        }
    }

    /// @notice Burns a token by a sender.
    /// @dev Note: This function implements {ERC721Burnable-burnFrom(address,uint256)}.
    /// @dev Reverts with {ERC721NonOwnedToken} if `tokenId` is not owned by `from`.
    /// @dev Reverts with {ERC721NonApprovedForTransfer} if `sender` is not `from` and has not been approved by `from` for `tokenId`.
    /// @dev Emits a {Transfer} event with `to` set to the zero address.
    /// @param sender The message sender.
    /// @param from The current token owner.
    /// @param tokenId The identifier of the token to burn.
    function burnFrom(Layout storage s, address sender, address from, uint256 tokenId) internal {
        uint256 owner = s.owners[tokenId];
        if (!_tokenExists(owner)) revert ERC721NonExistingToken(tokenId);
        if (_tokenOwner(owner) != from) revert ERC721NonOwnedToken(from, tokenId);

        if (!_isOperatable(s, from, sender)) {
            if (!_tokenHasApproval(owner) || sender != s.approvals[tokenId]) revert ERC721NonApprovedForTransfer(sender, from, tokenId);
        }

        s.owners[tokenId] = BURNT_TOKEN_OWNER_VALUE;

        unchecked {
            // cannot underflow as balance is verified through TOKEN ownership
            --s.balances[from];
        }
        emit IERC721Events.Transfer(from, address(0), tokenId);
    }

    /// @notice Burns a batch of tokens by a sender.
    /// @dev Note: This function implements {ERC721Burnable-batchBurnFrom(address,uint256[])}.
    /// @dev Reverts with {ERC721NonOwnedToken} if one of `tokenIds` is not owned by `from`.
    /// @dev Reverts with {ERC721NonApprovedForTransfer} if `sender` is not `from` and has not been approved by `from` for each of `tokenIds`.
    /// @dev Emits a {Transfer} event with `to` set to the zero address for each of `tokenIds`.
    /// @param sender The message sender.
    /// @param from The current tokens owner.
    /// @param tokenIds The identifiers of the tokens to burn.
    function batchBurnFrom(Layout storage s, address sender, address from, uint256[] calldata tokenIds) internal {
        bool operatable = _isOperatable(s, from, sender);

        uint256 length = tokenIds.length;
        unchecked {
            for (uint256 i; i != length; ++i) {
                uint256 tokenId = tokenIds[i];
                uint256 owner = s.owners[tokenId];
                if (!_tokenExists(owner)) revert ERC721NonExistingToken(tokenId);
                if (_tokenOwner(owner) != from) revert ERC721NonOwnedToken(from, tokenId);
                if (!operatable) {
                    if (!_tokenHasApproval(owner) || sender != s.approvals[tokenId]) revert ERC721NonApprovedForTransfer(sender, from, tokenId);
                }
                s.owners[tokenId] = BURNT_TOKEN_OWNER_VALUE;
                emit IERC721Events.Transfer(from, address(0), tokenId);
            }

            if (length != 0) {
                s.balances[from] -= length;
            }
        }
    }

    /// @notice Gets the balance of an address.
    /// @dev Note: This function implements {ERC721-balanceOf(address)}.
    /// @dev Reverts with {ERC721BalanceOfAddressZero} if `owner` is the zero address.
    /// @param owner The address to query the balance of.
    /// @return balance The amount owned by the owner.
    function balanceOf(Layout storage s, address owner) internal view returns (uint256 balance) {
        if (owner == address(0)) revert ERC721BalanceOfAddressZero();
        return s.balances[owner];
    }

    /// @notice Gets the owner of a token.
    /// @dev Note: This function implements {ERC721-ownerOf(uint256)}.
    /// @dev Reverts with {ERC721NonExistingToken} if `tokenId` does not exist.
    /// @param tokenId The token identifier to query the owner of.
    /// @return tokenOwner The owner of the token.
    function ownerOf(Layout storage s, uint256 tokenId) internal view returns (address tokenOwner) {
        uint256 owner = s.owners[tokenId];
        if (!_tokenExists(owner)) revert ERC721NonExistingToken(tokenId);
        return _tokenOwner(owner);
    }

    /// @notice Gets the approved address for a token.
    /// @dev Note: This function implements {ERC721-getApproved(uint256)}.
    /// @dev Reverts with {ERC721NonExistingToken} if `tokenId` does not exist.
    /// @param tokenId The token identifier to query the approval of.
    /// @return approved The approved address for the token identifier, or the zero address if no approval is set.
    function getApproved(Layout storage s, uint256 tokenId) internal view returns (address approved) {
        uint256 owner = s.owners[tokenId];
        if (!_tokenExists(owner)) revert ERC721NonExistingToken(tokenId);
        if (_tokenHasApproval(owner)) {
            return s.approvals[tokenId];
        } else {
            return address(0);
        }
    }

    /// @notice Gets whether an operator is approved for all tokens by an owner.
    /// @dev Note: This function implements {ERC721-isApprovedForAll(address,address)}.
    /// @param owner The address which gives the approval for all tokens.
    /// @param operator The address which receives the approval for all tokens.
    /// @return approvedForAll Whether the operator is approved for all tokens by the owner.
    function isApprovedForAll(Layout storage s, address owner, address operator) internal view returns (bool approvedForAll) {
        return s.operators[owner][operator];
    }

    /// @notice Gets whether a token was burnt.
    /// @param tokenId The token identifier.
    /// @return tokenWasBurnt Whether the token was burnt.
    function wasBurnt(Layout storage s, uint256 tokenId) internal view returns (bool tokenWasBurnt) {
        return _tokenWasBurnt(s.owners[tokenId]);
    }

    function layout() internal pure returns (Layout storage s) {
        bytes32 position = LAYOUT_STORAGE_SLOT;
        assembly {
            s.slot := position
        }
    }

    /// @notice Calls {IERC721Receiver-onERC721Received} on a target contract.
    /// @dev Reverts with {ERC721SafeTransferRejected} if the call to the target fails, reverts or is rejected.
    /// @param sender The message sender.
    /// @param from Previous token owner.
    /// @param to New token owner.
    /// @param tokenId Identifier of the token transferred.
    /// @param data Optional data to send along with the receiver contract call.
    function _callOnERC721Received(address sender, address from, address to, uint256 tokenId, bytes memory data) private {
        if (IERC721Receiver(to).onERC721Received(sender, from, tokenId, data) != ERC721_RECEIVED) revert ERC721SafeTransferRejected(to, tokenId);
    }

    /// @notice Returns whether an account is authorised to make a transfer on behalf of an owner.
    /// @param owner The token owner.
    /// @param account The account to check the operatability of.
    /// @return operatable True if `account` is `owner` or is an operator for `owner`, false otherwise.
    function _isOperatable(Layout storage s, address owner, address account) private view returns (bool operatable) {
        return (owner == account) || s.operators[owner][account];
    }

    function _tokenOwner(uint256 owner) private pure returns (address tokenOwner) {
        return address(uint160(owner));
    }

    function _tokenExists(uint256 owner) private pure returns (bool tokenExists) {
        return uint160(owner) != 0;
    }

    function _tokenWasBurnt(uint256 owner) private pure returns (bool tokenWasBurnt) {
        return owner == BURNT_TOKEN_OWNER_VALUE;
    }

    function _tokenHasApproval(uint256 owner) private pure returns (bool tokenHasApproval) {
        return owner & TOKEN_APPROVAL_OWNER_FLAG != 0;
    }
}
