// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// mock class using BasicToken
contract StandardTokenMock is ERC20 {
    uint8 myDecimals;
    string myName;
    string mySymbol;

    constructor(
        address _initialAccount,
        uint256 _initialBalance,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20("mock token", "mock token") {
        _mint(_initialAccount, _initialBalance);
        myDecimals = _decimals;
        myName = _name;
        mySymbol = _symbol;
    }

    function name() public view virtual override returns (string memory) {
        return myName;
    }

    function symbol() public view virtual override returns (string memory) {
        return mySymbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return myDecimals;
    }

    function mint(address _to, uint256 _amount) external returns (uint256) {
        _mint(_to, _amount);
        return _amount;
    }

    function burn(address _from, uint256 _amount) external returns (uint256) {
        _burn(_from, _amount);
        return _amount;
    }
}
