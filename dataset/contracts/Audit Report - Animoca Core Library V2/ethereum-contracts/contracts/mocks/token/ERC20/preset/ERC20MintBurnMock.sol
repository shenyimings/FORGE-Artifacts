// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC20MintBurn} from "./../../../../token/ERC20/preset/ERC20MintBurn.sol";

contract ERC20MintBurnMock is ERC20MintBurn {
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        IForwarderRegistry forwarderRegistry
    ) ERC20MintBurn(tokenName, tokenSymbol, tokenDecimals, forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
