// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { Proxy } from '@axelar-network/axelar-utils-solidity/contracts/upgradables/Proxy.sol';
import { IUpgradable } from '@axelar-network/axelar-utils-solidity/contracts/interfaces/IUpgradable.sol';

contract TokenLinkerProxy is Proxy {
    function contractId() internal pure override returns (bytes32) {
        return keccak256('token-linker');
    }

    receive() external payable override {}
}
