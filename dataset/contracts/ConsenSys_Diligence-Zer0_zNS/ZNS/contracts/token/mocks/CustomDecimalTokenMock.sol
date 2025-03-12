// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// solhint-disable
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CustomDecimalTokenMock is ERC20 {
    uint8 private _decimals;

    uint256 private _totalSupplyBase = 10000000000000000000000;

    constructor(address owner, uint256 decimals) ERC20("VariedDecimalTokenMock", "VDTM") {
        _decimals = uint8(decimals);
        _mint(owner, totalSupply());
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupplyBase * 10 ** uint256(_decimals);
    }
}
