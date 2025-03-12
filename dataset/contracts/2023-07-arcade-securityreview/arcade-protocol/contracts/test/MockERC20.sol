// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract MockERC20 is ERC20Burnable {
    mapping(address => bool) public blacklisted;

    /**
     * @dev Initializes ERC20 token
     */
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    /**
     * @dev Creates `amount` new tokens for `to`. Public for any test to call.
     *
     * See {ERC20-_mint}.
     */
    function mint(address to, uint256 amount) public virtual {
        _mint(to, amount);
    }

    function setBlacklisted(address user, bool isBlacklisted) external {
        // Add name to blacklist, so they cannot send or receive tokens
        blacklisted[user] = isBlacklisted;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(!blacklisted[from], "Blacklisted");
        require(!blacklisted[to], "Blacklisted");
        super._beforeTokenTransfer(from, to, amount);
    }

}

contract MockERC20WithDecimals is ERC20PresetMinterPauser {
    uint8 private _decimals;

    /**
     * @dev Initializes ERC20 token
     */
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) ERC20PresetMinterPauser(name, symbol) {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
