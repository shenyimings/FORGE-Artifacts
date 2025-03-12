// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract FRX is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint private constant TOTAL_SUPPLY = 100*(10**7); // 1B
    uint private constant INITIAL_SUPPLY = 100*(10**4); // 1M
    uint8 private constant DECIMAL = 8;

    constructor() public ERC20("FRX", "FRX") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupDecimals(DECIMAL);
        _mint(msg.sender, INITIAL_SUPPLY*(10**uint(DECIMAL))); // 1M
    }

    function mint(address to, uint256 amount) public {
        require(hasRole(MINTER_ROLE, msg.sender));
        require(totalSupply() + amount <= TOTAL_SUPPLY*(10**uint(DECIMAL)));
        _mint(to, amount);
    }
}
