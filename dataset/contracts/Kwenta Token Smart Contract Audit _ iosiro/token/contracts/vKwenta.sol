// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./utils/ERC20.sol";

/// @notice Purpose of this contract was to mint vKwenta for the initial Aelin raise.
/// @dev This is a one time use contract and supply can never be increased.
contract vKwenta is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        address _beneficiary,
        uint256 _amount
    ) ERC20(_name, _symbol) {
        _mint(_beneficiary, _amount);
    }
}
