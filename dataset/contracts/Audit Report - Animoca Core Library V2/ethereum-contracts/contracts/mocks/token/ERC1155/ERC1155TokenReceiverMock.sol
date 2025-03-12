// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IERC1155TokenReceiver} from "./../../../token/ERC1155/interfaces/IERC1155TokenReceiver.sol";
import {ERC1155Storage} from "./../../../token/ERC1155/libraries/ERC1155Storage.sol";
import {ERC1155TokenReceiver} from "./../../../token/ERC1155/ERC1155TokenReceiver.sol";

/// @title ERC1155 Receiver Mock
contract ERC1155TokenReceiverMock is ERC1155TokenReceiver {
    bool internal immutable ACCEPT_1155;
    address internal immutable _TOKEN_ADDRESS_1155;

    event ERC1155Received(address operator, address from, uint256 id, uint256 value, bytes data);
    event ERC1155BatchReceived(address operator, address from, uint256[] ids, uint256[] values, bytes data);

    error WrongToken();

    constructor(bool accept1155, address tokenAddress) {
        ACCEPT_1155 = accept1155;
        _TOKEN_ADDRESS_1155 = tokenAddress;
    }

    //=================================================== ERC1155Receiver ====================================================//

    /// @inheritdoc IERC1155TokenReceiver
    /// @dev reverts if the sender is not the supported ERC1155 contract.
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public virtual override returns (bytes4) {
        if (msg.sender != _TOKEN_ADDRESS_1155) revert WrongToken();
        if (ACCEPT_1155) {
            emit ERC1155Received(operator, from, id, value, data);
            return ERC1155Storage.ERC1155_SINGLE_RECEIVED;
        } else {
            return 0x0;
        }
    }

    /// @inheritdoc IERC1155TokenReceiver
    /// @dev reverts if the sender is not the supported ERC1155 contract.
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes memory data
    ) public virtual override returns (bytes4) {
        if (msg.sender != _TOKEN_ADDRESS_1155) revert WrongToken();
        if (ACCEPT_1155) {
            emit ERC1155BatchReceived(operator, from, ids, values, data);
            return ERC1155Storage.ERC1155_BATCH_RECEIVED;
        } else {
            return 0x0;
        }
    }
}
