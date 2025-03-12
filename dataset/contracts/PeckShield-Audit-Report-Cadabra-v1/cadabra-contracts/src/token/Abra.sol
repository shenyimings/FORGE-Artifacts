// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@layerzerolabs/solidity-examples/contracts-upgradable/token/oft/OFTUpgradeable.sol";

contract Abra is Initializable, OFTUpgradeable {
    function initialize(uint _initialSupply, address _lzEndpoint) public initializer {
        __OFTUpgradeable_init("ABRA", "ABRA", _lzEndpoint);
        _mint(_msgSender(), _initialSupply);
    }
}