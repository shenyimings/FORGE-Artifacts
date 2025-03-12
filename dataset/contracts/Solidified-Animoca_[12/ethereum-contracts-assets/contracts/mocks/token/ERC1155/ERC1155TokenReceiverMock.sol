// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import {ERC1155TokenReceiver} from "../../../token/ERC1155/ERC1155TokenReceiver.sol";

contract ERC1155TokenReceiverMock is ERC1155TokenReceiver {
    event ReceivedSingle(address operator, address from, uint256 id, uint256 value, bytes data, uint256 gas);

    event ReceivedBatch(address operator, address from, uint256[] ids, uint256[] values, bytes data, uint256 gas);

    bool internal _accept1155;

    constructor(bool accept1155) ERC1155TokenReceiver() {
        _accept1155 = accept1155;
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public virtual override returns (bytes4) {
        if (_accept1155) {
            emit ReceivedSingle(operator, from, id, value, data, gasleft());
            return _ERC1155_RECEIVED;
        } else {
            return _ERC1155_REJECTED;
        }
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual override returns (bytes4) {
        if (_accept1155) {
            emit ReceivedBatch(operator, from, ids, values, data, gasleft());
            return _ERC1155_BATCH_RECEIVED;
        } else {
            return _ERC1155_REJECTED;
        }
    }
}
