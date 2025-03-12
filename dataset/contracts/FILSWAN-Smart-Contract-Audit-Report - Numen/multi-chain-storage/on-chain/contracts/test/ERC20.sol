//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice simple ERC-20 contract for testing
/// @dev any caller can mint these tokens
contract TestERC20 is ERC20 {
    constructor (string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function mint(address user, uint256 amount) external returns (bool) {
        _mint(user, amount);
        return true;
    }
}