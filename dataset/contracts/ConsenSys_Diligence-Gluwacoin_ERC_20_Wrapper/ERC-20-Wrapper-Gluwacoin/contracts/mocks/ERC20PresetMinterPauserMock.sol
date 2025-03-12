// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ERC20PresetMinterPauserMockUpgradeSafe is Initializable, ERC20PresetMinterPauserUpgradeable {

    constructor(
        string memory name,
        string memory symbol
    ) {
        initialize(name, symbol);
    }
 

    function initialize(string memory name, string memory symbol) public override initializer {
        __Context_init_unchained();
        __AccessControl_init_unchained();
        __ERC20_init_unchained(name, symbol);
        __ERC20Burnable_init_unchained();
        __Pausable_init_unchained();
        __ERC20Pausable_init_unchained();
        __ERC20PresetMinterPauser_init_unchained(name, symbol);
    }


    uint256[50] private __gap;
}