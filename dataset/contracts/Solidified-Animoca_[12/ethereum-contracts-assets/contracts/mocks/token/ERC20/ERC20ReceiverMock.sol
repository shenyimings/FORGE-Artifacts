// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import {ManagedIdentity} from "@animoca/ethereum-contracts-core-1.1.1/contracts/metatx/ManagedIdentity.sol";
import {ERC20Receiver} from "../../../token/ERC20/ERC20Receiver.sol";

contract ERC20ReceiverMock is ERC20Receiver, ManagedIdentity {
    event ERC20Received(address sender, address from, uint256 value, bytes data, uint256 gas);

    bool internal _accept;
    address internal _tokenAddress;

    constructor(bool accept, address tokenAddress) {
        _accept = accept;
        _tokenAddress = tokenAddress;
    }

    function onERC20Received(
        address sender,
        address from,
        uint256 value,
        bytes memory data
    ) public virtual override returns (bytes4) {
        require(_msgSender() == _tokenAddress, "ERC20Receiver: wrong token");
        if (_accept) {
            emit ERC20Received(sender, from, value, data, gasleft());
            return _ERC20_RECEIVED;
        } else {
            return _ERC20_REJECTED;
        }
    }
}
