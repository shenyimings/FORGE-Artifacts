// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title A contract of the ERC20 token
/// @author Ustaking team
/// @dev the standard contract of the ERC20 token with AccessControls
contract UStakingToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public constant MAX_SUPPLY = 2000000000e18;


    /// @notice Constructor for create ERC20
    /// @dev the constructor that creates the token adds a name, symbol, issue and adds a role for the token owner
    constructor() ERC20("uStaking", "uSTK") {
        _mint(msg.sender, 150010000 * 10 ** decimals());
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }
    /// @notice function for the mint of new tokens
    /// @dev mintin function new tokens to the address
    /// @param to the address where the new tokens will be sent
    /// @param amount the number of tokens that will be sent
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
         require(MAX_SUPPLY >= totalSupply() + (amount), "max supply exceed");
        _mint(to, amount);
    }
}