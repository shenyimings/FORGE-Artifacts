// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

/**
 * @notice Token preset used in tests. You can ignore this contract.
 */
contract TestToken is ERC20PresetFixedSupply {
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        address _owner
    ) ERC20PresetFixedSupply(_name, _symbol, _initialSupply, _owner) {}
}
