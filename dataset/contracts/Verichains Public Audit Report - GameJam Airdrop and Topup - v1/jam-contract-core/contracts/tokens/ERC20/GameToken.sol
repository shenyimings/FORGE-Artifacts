/* SPDX-License-Identifier: MIT */

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract GameToken is AccessControl, ERC20Burnable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC20("GameToken", "IDLE") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address recipient, uint256 amount) external {
        require(
            hasRole(MINTER_ROLE, msg.sender),
            "GameToken: caller is not minter"
        );
        _mint(recipient, amount);
    }
}
