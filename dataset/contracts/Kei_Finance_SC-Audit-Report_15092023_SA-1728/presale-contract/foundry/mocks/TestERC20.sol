// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    uint8 private _decimals;
    bool private customDecimals;

    event Token_Called(string name, string symbol, uint8 decimals);

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function setDecimals(uint8 newDecimals) public {
        customDecimals = true;
        _decimals = newDecimals;
    }

    function unsetDecimals() public {
        customDecimals = false;
        _decimals = 0;
    }

    function decimals() public view virtual override returns (uint8 currentDecimals) {
        currentDecimals = customDecimals ? _decimals : super.decimals();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        emit Token_Called(name(), symbol(), decimals());
        super._beforeTokenTransfer(from, to, amount);
    }
}
