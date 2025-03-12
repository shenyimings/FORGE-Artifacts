// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { TokenLinker } from './TokenLinker.sol';
import { ERC20 } from '@axelar-network/axelar-cgp-solidity/contracts/ERC20.sol';

contract TokenLinkerMintBurn is TokenLinker, ERC20 {
    error MintFailed();
    error BurnFailed();

    constructor(
        address gatewayAddress_,
        address gasServiceAddress_,
        uint8 decimals_
    ) TokenLinker(gatewayAddress_, gasServiceAddress_) ERC20('', '', decimals_) {}

    function _setup(bytes calldata data) internal override {
        (name, symbol) = abi.decode(data, (string, string));
    }

    function _giveToken(address to, uint256 amount) internal override {
        _mint(to, amount);
    }

    function _takeToken(address from, uint256 amount) internal override {
        _burn(from, amount);
    }
}
