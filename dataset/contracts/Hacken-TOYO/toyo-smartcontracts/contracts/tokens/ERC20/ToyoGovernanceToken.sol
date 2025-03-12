// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ToyoGovernanceToken is ERC20PresetMinterPauserUpgradeable, OwnableUpgradeable
{
    function initialize(string memory _name, string memory _symbol) override public initializer {
        __ERC20_init(_name, _symbol);
        __ERC20PresetMinterPauser_init(_name, _symbol);
        __AccessControl_init();
        __Ownable_init();
        __Pausable_init();
    }
}