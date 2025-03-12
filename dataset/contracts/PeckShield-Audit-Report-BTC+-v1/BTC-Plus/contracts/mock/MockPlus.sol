// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "../Plus.sol";
import "./MockToken.sol";

/**
 * @dev Mock plus implementation.
 */
contract MockPlus is Plus {
    uint256 public underlyingAmount;

    function initialize(string memory _name, string memory _symbol) public {
        __PlusToken__init(_name, _symbol);
    }

    /**
     * @dev Returns the total value of the plus token in terms of the peg value.
     * All underlying token amounts have been scaled to 18 decimals.
     * For single plus, it's equal to its total supply.
     * For composite plus, it's equal to the total amount of single plus tokens in its basket.
     */
    function _totalUnderlyingInWad() internal view virtual override returns (uint256) {
        return underlyingAmount * WAD;
    }

    function increment(uint256 amount) public {
        underlyingAmount = underlyingAmount + amount;
    }

    function mintShares(address user, uint256 amount) public {
        totalShares += amount;
        userShare[user] += amount;
        underlyingAmount += amount * index / WAD; 
    }

    /**
     * @dev Checks whether a token can be salvaged via salvageToken().
     * @param _token Token to check salvageability.
     */
    function _salvageable(address _token) internal view override returns (bool) {
        underlyingAmount;
        return _token != address(0x0);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }
}