// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC1363ReceiverUpgradeable.sol";

/// @title ERC1363ReceiverMock implementation
/// @dev Mock class using IERC1363Receiver
contract ERC1363ReceiverMock is IERC1363ReceiverUpgradeable {
    bytes4 private _retval;
    bool private _reverts;

    event Received(address operator, address sender, uint256 amount, bytes data, uint256 gas);

    constructor(bytes4 retval, bool reverts) {
        _retval = retval;
        _reverts = reverts;
    }

    function onTransferReceived(
        address spender,
        address sender,
        uint256 amount,
        bytes memory data
    ) public override returns (bytes4) {
        require(!_reverts, "ERC1363ReceiverMock: throwing");
        emit Received(spender, sender, amount, data, 1000000000);
        return _retval;
    }
}
