// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../metatx/interfaces/IForwarderRegistry.sol";
import {IERC677} from "./../../../token/ERC20/interfaces/IERC677.sol";
import {IERC677Receiver} from "./../../../token/ERC20/interfaces/IERC677Receiver.sol";
import {ERC20Storage} from "./../../../token/ERC20/libraries/ERC20Storage.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC20FixedSupply} from "./../../../token/ERC20/preset/ERC20FixedSupply.sol";

contract ERC677Mock is ERC20FixedSupply, IERC677 {
    using ERC20Storage for ERC20Storage.Layout;
    using Address for address;

    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        address[] memory holders,
        uint256[] memory allocations,
        IForwarderRegistry forwarderRegistry
    ) ERC20FixedSupply(tokenName, tokenSymbol, tokenDecimals, holders, allocations, forwarderRegistry) {}

    function transferAndCall(address receiver, uint256 amount, bytes calldata data) external returns (bool success) {
        address sender = _msgSender();
        ERC20Storage.layout().transfer(sender, receiver, amount);
        if (!receiver.isContract()) return true;
        return IERC677Receiver(receiver).onTokenTransfer(sender, amount, data);
    }
}
