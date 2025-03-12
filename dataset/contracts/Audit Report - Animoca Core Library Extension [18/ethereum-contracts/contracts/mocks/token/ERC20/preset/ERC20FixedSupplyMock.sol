// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC20FixedSupply} from "./../../../../token/ERC20/preset/ERC20FixedSupply.sol";

contract ERC20FixedSupplyMock is ERC20FixedSupply {
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        address[] memory holders,
        uint256[] memory allocations,
        IForwarderRegistry forwarderRegistry
    ) ERC20FixedSupply(tokenName, tokenSymbol, tokenDecimals, holders, allocations, forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
