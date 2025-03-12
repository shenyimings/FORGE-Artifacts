// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// solhint-disable-next-line max-line-length
import {ERC1155SelfApprovalForAll, ERC1155TransferToAddressZero, ERC1155NonApproved, ERC1155InsufficientBalance, ERC1155BalanceOverflow, ERC1155SafeTransferRejected, ERC1155SafeBatchTransferRejected, ERC1155BalanceOfAddressZero} from "./../errors/ERC1155Errors.sol";
import {ERC1155MintToAddressZero} from "./../errors/ERC1155MintableErrors.sol";
import {InconsistentArrayLengths} from "./../../../CommonErrors.sol";
import {IERC1155Events} from "./../events/IERC1155Events.sol";
import {IERC1155} from "./../interfaces/IERC1155.sol";
import {IERC1155MetadataURI} from "./../interfaces/IERC1155MetadataURI.sol";
import {IERC1155Mintable} from "./../interfaces/IERC1155Mintable.sol";
import {IERC1155Deliverable} from "./../interfaces/IERC1155Deliverable.sol";
import {IERC1155Burnable} from "./../interfaces/IERC1155Burnable.sol";
import {IERC1155TokenReceiver} from "./../interfaces/IERC1155TokenReceiver.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {InterfaceDetectionStorage} from "./../../../introspection/libraries/InterfaceDetectionStorage.sol";

library ERC1155Storage {
    using Address for address;
    using ERC1155Storage for ERC1155Storage.Layout;
    using InterfaceDetectionStorage for InterfaceDetectionStorage.Layout;

    struct Layout {
        mapping(uint256 => mapping(address => uint256)) balances;
        mapping(address => mapping(address => bool)) operators;
    }

    bytes32 internal constant LAYOUT_STORAGE_SLOT = bytes32(uint256(keccak256("animoca.token.ERC1155.ERC1155.storage")) - 1);

    bytes4 internal constant ERC1155_SINGLE_RECEIVED = IERC1155TokenReceiver.onERC1155Received.selector;
    bytes4 internal constant ERC1155_BATCH_RECEIVED = IERC1155TokenReceiver.onERC1155BatchReceived.selector;

    /// @notice Marks the following ERC165 interface(s) as supported: ERC1155.
    function init() internal {
        InterfaceDetectionStorage.layout().setSupportedInterface(type(IERC1155).interfaceId, true);
    }

    /// @notice Marks the following ERC165 interface(s) as supported: ERC1155MetadataURI.
    function initERC1155MetadataURI() internal {
        InterfaceDetectionStorage.layout().setSupportedInterface(type(IERC1155MetadataURI).interfaceId, true);
    }

    /// @notice Marks the following ERC165 interface(s) as supported: ERC1155Mintable.
    function initERC1155Mintable() internal {
        InterfaceDetectionStorage.layout().setSupportedInterface(type(IERC1155Mintable).interfaceId, true);
    }

    /// @notice Marks the following ERC165 interface(s) as supported: ERC1155Deliverable.
    function initERC1155Deliverable() internal {
        InterfaceDetectionStorage.layout().setSupportedInterface(type(IERC1155Deliverable).interfaceId, true);
    }

    /// @notice Marks the following ERC165 interface(s) as supported: ERC1155Burnable.
    function initERC1155Burnable() internal {
        InterfaceDetectionStorage.layout().setSupportedInterface(type(IERC1155Burnable).interfaceId, true);
    }

    /// @notice Safely transfers some token by a sender.
    /// @dev Note: This function implements {ERC1155-safeTransferFrom(address,address,uint256,uint256,bytes)}.
    /// @dev Warning: Since a `to` contract can run arbitrary code, developers should be aware of potential re-entrancy attacks.
    /// @dev Reverts with {ERC1155TransferToAddressZero} if `to` is the zero address.
    /// @dev Reverts with {ERC1155NonApproved} if `sender` is not `from` and has not been approved by `from`.
    /// @dev Reverts with {ERC1155InsufficientBalance} if `from` has an insufficient balance of `id`.
    /// @dev Reverts with {ERC1155BalanceOverflow} if `to`'s balance of `id` overflows.
    /// @dev Reverts with {ERC1155SafeTransferRejected} if `to` is a contract and the call to
    ///  {IERC1155TokenReceiver-onERC1155Received} fails, reverts or is rejected.
    /// @dev Emits a {TransferSingle} event.
    /// @param sender The message sender.
    /// @param from Current token owner.
    /// @param to Address of the new token owner.
    /// @param id Identifier of the token to transfer.
    /// @param value Amount of token to transfer.
    /// @param data Optional data to send along to a receiver contract.
    function safeTransferFrom(Layout storage s, address sender, address from, address to, uint256 id, uint256 value, bytes calldata data) internal {
        if (to == address(0)) revert ERC1155TransferToAddressZero();
        if (!_isOperatable(s, from, sender)) revert ERC1155NonApproved(sender, from);

        _transferToken(s, from, to, id, value);

        emit IERC1155Events.TransferSingle(sender, from, to, id, value);

        if (to.isContract()) {
            _callOnERC1155Received(sender, from, to, id, value, data);
        }
    }

    /// @notice Safely transfers a batch of tokens by a sender.
    /// @dev Note: This function implements {ERC1155-safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)}.
    /// @dev Warning: Since a `to` contract can run arbitrary code, developers should be aware of potential re-entrancy attacks.
    /// @dev Reverts with {ERC1155TransferToAddressZero} if `to` is the zero address.
    /// @dev Reverts with {InconsistentArrayLengths} if `ids` and `values` have different lengths.
    /// @dev Reverts with {ERC1155NonApproved} if `sender` is not `from` and has not been approved by `from`.
    /// @dev Reverts with {ERC1155InsufficientBalance} if `from` has an insufficient balance for any of `ids`.
    /// @dev Reverts with {ERC1155BalanceOverflow} if `to`'s balance of any of `ids` overflows.
    /// @dev Reverts with {ERC1155SafeBatchTransferRejected} if `to` is a contract and the call to
    ///  {IERC1155TokenReceiver-onERC1155BatchReceived} fails, reverts or is rejected.
    /// @dev Emits a {TransferBatch} event.
    /// @param sender The message sender.
    /// @param from Current tokens owner.
    /// @param to Address of the new tokens owner.
    /// @param ids Identifiers of the tokens to transfer.
    /// @param values Amounts of tokens to transfer.
    /// @param data Optional data to send along to a receiver contract.
    function safeBatchTransferFrom(
        Layout storage s,
        address sender,
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) internal {
        if (to == address(0)) revert ERC1155TransferToAddressZero();
        uint256 length = ids.length;
        if (length != values.length) revert InconsistentArrayLengths();

        if (!_isOperatable(s, from, sender)) revert ERC1155NonApproved(sender, from);

        unchecked {
            for (uint256 i; i != length; ++i) {
                _transferToken(s, from, to, ids[i], values[i]);
            }
        }

        emit IERC1155Events.TransferBatch(sender, from, to, ids, values);

        if (to.isContract()) {
            _callOnERC1155BatchReceived(sender, from, to, ids, values, data);
        }
    }

    /// @notice Safely mints some token by a sender.
    /// @dev Note: This function implements {ERC1155Mintable-safeMint(address,uint256,uint256,bytes)}.
    /// @dev Warning: Since a `to` contract can run arbitrary code, developers should be aware of potential re-entrancy attacks.
    /// @dev Reverts with {ERC1155MintToAddressZero} if `to` is the zero address.
    /// @dev Reverts with {ERC1155BalanceOverflow} if `to`'s balance of `id` overflows.
    /// @dev Reverts with {ERC1155SafeTransferRejected} if `to` is a contract and the call to
    ///  {IERC1155TokenReceiver-onERC1155Received} fails, reverts or is rejected.
    /// @dev Emits a {TransferSingle} event.
    /// @param sender The message sender.
    /// @param to Address of the new token owner.
    /// @param id Identifier of the token to mint.
    /// @param value Amount of token to mint.
    /// @param data Optional data to send along to a receiver contract.
    function safeMint(Layout storage s, address sender, address to, uint256 id, uint256 value, bytes memory data) internal {
        if (to == address(0)) revert ERC1155MintToAddressZero();

        _mintToken(s, to, id, value);

        emit IERC1155Events.TransferSingle(sender, address(0), to, id, value);

        if (to.isContract()) {
            _callOnERC1155Received(sender, address(0), to, id, value, data);
        }
    }

    /// @notice Safely mints a batch of tokens by a sender.
    /// @dev Note: This function implements {ERC1155Mintable-safeBatchMint(address,uint256[],uint256[],bytes)}.
    /// @dev Warning: Since a `to` contract can run arbitrary code, developers should be aware of potential re-entrancy attacks.
    /// @dev Reverts with {ERC1155MintToAddressZero} if `to` is the zero address.
    /// @dev Reverts with {InconsistentArrayLengths} if `ids` and `values` have different lengths.
    /// @dev Reverts with {ERC1155BalanceOverflow} if `to`'s balance overflows for one of `ids`.
    /// @dev Reverts with {ERC1155SafeBatchTransferRejected} if `to` is a contract and the call to
    ///  {IERC1155TokenReceiver-onERC1155batchReceived} fails, reverts or is rejected.
    /// @dev Emits a {TransferBatch} event.
    /// @param sender The message sender.
    /// @param to Address of the new tokens owner.
    /// @param ids Identifiers of the tokens to mint.
    /// @param values Amounts of tokens to mint.
    /// @param data Optional data to send along to a receiver contract.
    function safeBatchMint(Layout storage s, address sender, address to, uint256[] memory ids, uint256[] memory values, bytes memory data) internal {
        if (to == address(0)) revert ERC1155MintToAddressZero();
        uint256 length = ids.length;
        if (length != values.length) revert InconsistentArrayLengths();

        unchecked {
            for (uint256 i; i != length; ++i) {
                _mintToken(s, to, ids[i], values[i]);
            }
        }

        emit IERC1155Events.TransferBatch(sender, address(0), to, ids, values);

        if (to.isContract()) {
            _callOnERC1155BatchReceived(sender, address(0), to, ids, values, data);
        }
    }

    /// @notice Safely mints tokens to multiple recipients by a sender.
    /// @dev Note: This function implements {ERC1155Deliverable-safeDeliver(address[],uint256[],uint256[],bytes)}.
    /// @dev Warning: Since a `to` contract can run arbitrary code, developers should be aware of potential re-entrancy attacks.
    /// @dev Reverts with {InconsistentArrayLengths} if `recipients`, `ids` and `values` have different lengths.
    /// @dev Reverts with {ERC1155MintToAddressZero} if one of `recipients` is the zero address.
    /// @dev Reverts with {ERC1155BalanceOverflow} if one of the `recipients`' balance overflows for the associated `ids`.
    /// @dev Reverts with {ERC1155SafeTransferRejected} if one of `recipients` is a contract and the call to
    ///  {IERC1155TokenReceiver-onERC1155Received} fails, reverts or is rejected.
    /// @dev Emits a {TransferSingle} event from the zero address for each transfer.
    /// @param sender The message sender.
    /// @param recipients Addresses of the new tokens owners.
    /// @param ids Identifiers of the tokens to mint.
    /// @param values Amounts of tokens to mint.
    /// @param data Optional data to send along to a receiver contract.
    function safeDeliver(
        Layout storage s,
        address sender,
        address[] memory recipients,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal {
        uint256 length = recipients.length;
        if (length != ids.length || length != values.length) revert InconsistentArrayLengths();
        unchecked {
            for (uint256 i; i != length; ++i) {
                s.safeMint(sender, recipients[i], ids[i], values[i], data);
            }
        }
    }

    /// @notice Burns some token by a sender.
    /// @dev Reverts with {ERC1155NonApproved} if `sender` is not `from` and has not been approved by `from`.
    /// @dev Reverts with {ERC1155InsufficientBalance} if `from` has an insufficient balance of `id`.
    /// @dev Emits a {TransferSingle} event.
    /// @param sender The message sender.
    /// @param from Address of the current token owner.
    /// @param id Identifier of the token to burn.
    /// @param value Amount of token to burn.
    function burnFrom(Layout storage s, address sender, address from, uint256 id, uint256 value) internal {
        if (!_isOperatable(s, from, sender)) revert ERC1155NonApproved(sender, from);
        _burnToken(s, from, id, value);
        emit IERC1155Events.TransferSingle(sender, from, address(0), id, value);
    }

    /// @notice Burns multiple tokens by a sender.
    /// @dev Reverts with {InconsistentArrayLengths} if `ids` and `values` have different lengths.
    /// @dev Reverts with {ERC1155NonApproved} if `sender` is not `from` and has not been approved by `from`.
    /// @dev Reverts with {ERC1155InsufficientBalance} if `from` has an insufficient balance for any of `ids`.
    /// @dev Emits an {IERC1155-TransferBatch} event.
    /// @param sender The message sender.
    /// @param from Address of the current tokens owner.
    /// @param ids Identifiers of the tokens to burn.
    /// @param values Amounts of tokens to burn.
    function batchBurnFrom(Layout storage s, address sender, address from, uint256[] calldata ids, uint256[] calldata values) internal {
        uint256 length = ids.length;
        if (length != values.length) revert InconsistentArrayLengths();
        if (!_isOperatable(s, from, sender)) revert ERC1155NonApproved(sender, from);

        unchecked {
            for (uint256 i; i != length; ++i) {
                _burnToken(s, from, ids[i], values[i]);
            }
        }

        emit IERC1155Events.TransferBatch(sender, from, address(0), ids, values);
    }

    /// @notice Enables or disables an operator's approval by a sender.
    /// @dev Reverts with {ERC1155SelfApprovalForAll} if `sender` is `operator`.
    /// @dev Emits an {ApprovalForAll} event.
    /// @param sender The message sender.
    /// @param operator Address of the operator.
    /// @param approved True to approve the operator, false to revoke its approval.
    function setApprovalForAll(Layout storage s, address sender, address operator, bool approved) internal {
        if (operator == sender) revert ERC1155SelfApprovalForAll(sender);
        s.operators[sender][operator] = approved;
        emit IERC1155Events.ApprovalForAll(sender, operator, approved);
    }

    /// @notice Retrieves the approval status of an operator for a given owner.
    /// @param owner Address of the authorisation giver.
    /// @param operator Address of the operator.
    /// @return approved True if the operator is approved, false if not.
    function isApprovedForAll(Layout storage s, address owner, address operator) internal view returns (bool approved) {
        return s.operators[owner][operator];
    }

    /// @notice Retrieves the balance of `id` owned by account `owner`.
    /// @dev Reverts with {ERC1155BalanceOfAddressZero} if `owner` is the zero address.
    /// @param owner The account to retrieve the balance of.
    /// @param id The identifier to retrieve the balance of.
    /// @return balance The balance of `id` owned by account `owner`.
    function balanceOf(Layout storage s, address owner, uint256 id) internal view returns (uint256 balance) {
        if (owner == address(0)) revert ERC1155BalanceOfAddressZero();
        return s.balances[id][owner];
    }

    /// @notice Retrieves the balances of `ids` owned by accounts `owners`.
    /// @dev Reverts with {InconsistentArrayLengths} if `owners` and `ids` have different lengths.
    /// @dev Reverts with {ERC1155BalanceOfAddressZero} if one of `owners` is the zero address.
    /// @param owners The addresses of the token holders
    /// @param ids The identifiers to retrieve the balance of.
    /// @return balances The balances of `ids` owned by accounts `owners`.
    function balanceOfBatch(Layout storage s, address[] calldata owners, uint256[] calldata ids) internal view returns (uint256[] memory balances) {
        uint256 length = owners.length;
        if (length != ids.length) revert InconsistentArrayLengths();

        balances = new uint256[](owners.length);

        unchecked {
            for (uint256 i; i != length; ++i) {
                balances[i] = s.balanceOf(owners[i], ids[i]);
            }
        }
    }

    function layout() internal pure returns (Layout storage s) {
        bytes32 position = LAYOUT_STORAGE_SLOT;
        assembly {
            s.slot := position
        }
    }

    /// @notice Returns whether an account is authorised to make a transfer on behalf of an owner.
    /// @param owner The token owner.
    /// @param account The account to check the operatability of.
    /// @return operatable True if `account` is `owner` or is an operator for `owner`, false otherwise.
    function _isOperatable(Layout storage s, address owner, address account) private view returns (bool operatable) {
        return (owner == account) || s.operators[owner][account];
    }

    function _transferToken(Layout storage s, address from, address to, uint256 id, uint256 value) private {
        if (value != 0) {
            unchecked {
                uint256 fromBalance = s.balances[id][from];
                uint256 newFromBalance = fromBalance - value;
                if (newFromBalance >= fromBalance) revert ERC1155InsufficientBalance(from, id, fromBalance, value);
                if (from != to) {
                    uint256 toBalance = s.balances[id][to];
                    uint256 newToBalance = toBalance + value;
                    if (newToBalance <= toBalance) revert ERC1155BalanceOverflow(to, id, toBalance, value);

                    s.balances[id][from] = newFromBalance;
                    s.balances[id][to] = newToBalance;
                }
            }
        }
    }

    function _mintToken(Layout storage s, address to, uint256 id, uint256 value) private {
        if (value != 0) {
            unchecked {
                uint256 balance = s.balances[id][to];
                uint256 newBalance = balance + value;
                if (newBalance <= balance) revert ERC1155BalanceOverflow(to, id, balance, value);
                s.balances[id][to] = newBalance;
            }
        }
    }

    function _burnToken(Layout storage s, address from, uint256 id, uint256 value) private {
        if (value != 0) {
            unchecked {
                uint256 balance = s.balances[id][from];
                uint256 newBalance = balance - value;
                if (newBalance >= balance) revert ERC1155InsufficientBalance(from, id, balance, value);
                s.balances[id][from] = newBalance;
            }
        }
    }

    /// @notice Calls {IERC1155TokenReceiver-onERC1155Received} on a target contract.
    /// @dev Reverts with {ERC1155SafeTransferRejected} if the call to the target fails, reverts or is rejected.
    /// @param sender The message sender.
    /// @param from Previous token owner.
    /// @param to New token owner.
    /// @param id Identifier of the token transferred.
    /// @param value Value transferred.
    /// @param data Optional data to send along with the receiver contract call.
    function _callOnERC1155Received(address sender, address from, address to, uint256 id, uint256 value, bytes memory data) private {
        if (IERC1155TokenReceiver(to).onERC1155Received(sender, from, id, value, data) != ERC1155_SINGLE_RECEIVED)
            revert ERC1155SafeTransferRejected(to, id, value);
    }

    /// @notice Calls {IERC1155TokenReceiver-onERC1155BatchReceived} on a target contract.
    /// @dev Reverts with {ERC1155SafeBatchTransferRejected} if the call to the target fails, reverts or is rejected.
    /// @param sender The message sender.
    /// @param from Previous token owner.
    /// @param to New token owner.
    /// @param ids Identifiers of the tokens transferred.
    /// @param values Values transferred.
    /// @param data Optional data to send along with the receiver contract call.
    function _callOnERC1155BatchReceived(
        address sender,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) private {
        if (IERC1155TokenReceiver(to).onERC1155BatchReceived(sender, from, ids, values, data) != ERC1155_BATCH_RECEIVED)
            revert ERC1155SafeBatchTransferRejected(to, ids, values);
    }
}
