// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

// interfaces
import {IVQuote} from "../interfaces/IVQuote.sol";

// contracts
import {VirtualToken} from "./VirtualToken.sol";

/// @notice ERC20 token traded on the CryptoSwap pool
contract VQuote is IVQuote, VirtualToken {
    constructor(string memory _name, string memory _symbol) VirtualToken(_name, _symbol) {}
}
