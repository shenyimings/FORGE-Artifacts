// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC20Receiver} from "./../../../token/ERC20/interfaces/IERC20Receiver.sol";
import {ERC20Storage} from "./../../../token/ERC20/libraries/ERC20Storage.sol";
import {ERC20Receiver} from "./../../../token/ERC20/ERC20Receiver.sol";

/// @title ERC20 Receiver Mock.
contract ERC20ReceiverMock is ERC20Receiver {
    bool internal immutable _ACCCEPT;
    address internal immutable _TOKEN_ADDRESS;

    event ERC20Received(address sender, address from, uint256 value, bytes data);

    error WrongToken();

    constructor(bool accept, address tokenAddress) {
        _ACCCEPT = accept;
        _TOKEN_ADDRESS = tokenAddress;
    }

    //==================================================== ERC20Receiver ====================================================//

    /// @inheritdoc IERC20Receiver
    function onERC20Received(address sender, address from, uint256 value, bytes memory data) public virtual override returns (bytes4) {
        if (msg.sender != _TOKEN_ADDRESS) revert WrongToken();
        if (_ACCCEPT) {
            emit ERC20Received(sender, from, value, data);
            return ERC20Storage.ERC20_RECEIVED;
        } else {
            return 0x0;
        }
    }
}
