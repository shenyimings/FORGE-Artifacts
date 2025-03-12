//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract ERC20Sample is OwnableUpgradeable, ERC20Upgradeable {
    function initialize(string memory name_, string memory symbol_, uint256 totalSupply_, address owner_) public virtual initializer {
        __Ownable_init_unchained();
        transferOwnership(owner_);
        __ERC20_init(name_, symbol_);
        _mint(owner_, totalSupply_);
    }
}
