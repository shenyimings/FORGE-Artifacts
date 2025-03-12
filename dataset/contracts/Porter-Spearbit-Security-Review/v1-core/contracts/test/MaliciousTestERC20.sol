//SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MaliciousTestERC20 is ERC20 {
    uint8 private _decimals = 18;

    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _mintAmount,
        uint8 decimals_
    ) ERC20(_tokenName, _tokenSymbol) {
        _mint(msg.sender, _mintAmount);
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, 0);
        return true;
    }
}
