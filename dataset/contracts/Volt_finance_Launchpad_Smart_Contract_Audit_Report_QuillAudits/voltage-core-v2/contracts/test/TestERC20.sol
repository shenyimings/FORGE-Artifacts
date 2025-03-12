// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    uint8 public _decimals;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _dec,
        uint256 amountToMint
    ) ERC20(_name, _symbol) {
        setDecimals(_dec);
        setBalance(msg.sender, amountToMint);
    }

    function setDecimals(uint8 _dec) public {
        _decimals = _dec;
    }

    function decimals() public override view returns(uint8) {
        return _decimals;
    }

    function setBalance(address to, uint256 amount) public {
        uint256 old = balanceOf(to);
        if (old < amount) {
            _mint(to, amount - old);
        } else if (old > amount) {
            _burn(to, old - amount);
        }
    }
}
