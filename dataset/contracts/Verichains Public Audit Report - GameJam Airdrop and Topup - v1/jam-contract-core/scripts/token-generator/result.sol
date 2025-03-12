/* SPDX-License-Identifier: MIT */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract JamNFT is AccessControl, ERC20Capped, ERC20Burnable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC20("JamNFT", "JNFT") ERC20Capped(3000000000 * 10**18) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address recipient, uint256 amount) external {
        require(
            hasRole(MINTER_ROLE, msg.sender),
            "JamNFT: caller is not minter"
        );
        _mint(recipient, amount);
    }

    function _mint(address recipient, uint256 amount)
        internal
        override(ERC20, ERC20Capped)
    {
        ERC20Capped._mint(recipient, amount);
    }
}
