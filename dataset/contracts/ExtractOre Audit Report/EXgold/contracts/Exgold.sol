// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

// Import base ERC20 Upgradeable contract
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";

contract Exgold is ERC20UpgradeSafe {
    string private _name;
    string private _symbol;
    uint256 private constant _totalSupply = 5000000;
    uint256 private constant _decimals = 6;

    /**
     * @dev  Initializer function (replaces constructor)
     * Sets the values for {name} and {symbol}, initializes {decimals} using {_setupDecimals}
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    function initialize(string memory name, string memory symbol)
        public
        initializer
    {
        _name = name;
        _symbol = symbol;
        __ERC20_init(_name, _symbol);
        _setupDecimals(6);
        _mint(msg.sender, _totalSupply * (10**uint256(_decimals)));
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }
}
