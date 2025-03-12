// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Errors} from "@src/libraries/Errors.sol";

/// @title NonTransferrableToken
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice An ERC-20 that is not transferrable from outside of the protocol
/// @dev The contract owner (i.e. the Size contract) can still mint, burn, and transfer tokens
contract NonTransferrableToken is Ownable, ERC20 {
    uint8 internal immutable _decimals;

    // solhint-disable-next-line no-empty-blocks
    constructor(address owner_, string memory name_, string memory symbol_, uint8 decimals_)
        Ownable(owner_)
        ERC20(name_, symbol_)
    {
        if (decimals_ == 0) {
            revert Errors.NULL_AMOUNT();
        }

        _decimals = decimals_;
    }

    function mint(address to, uint256 value) external virtual onlyOwner {
        _mint(to, value);
    }

    function burn(address from, uint256 value) external virtual onlyOwner {
        _burn(from, value);
    }

    function transferFrom(address from, address to, uint256 value) public virtual override onlyOwner returns (bool) {
        _transfer(from, to, value);
        return true;
    }

    function transfer(address to, uint256 value) public virtual override onlyOwner returns (bool) {
        return transferFrom(msg.sender, to, value);
    }

    function allowance(address, address spender) public view virtual override returns (uint256) {
        return spender == owner() ? type(uint256).max : 0;
    }

    function approve(address, uint256) public virtual override returns (bool) {
        revert Errors.NOT_SUPPORTED();
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
