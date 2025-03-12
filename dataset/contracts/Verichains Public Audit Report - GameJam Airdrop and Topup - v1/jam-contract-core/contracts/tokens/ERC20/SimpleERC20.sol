// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleERC20 is ERC20, ERC20Burnable, Ownable {
    using SafeMath for uint256;

    uint256 private _totalMinted;
    uint256 private _cap;
    uint8 private _decimals;
    address public coinTokenAddress;

    constructor(
        address _owner,
        uint256 capacity,
        uint256 initialSupply,
        uint8 decimal,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        transferOwnership(payable(_owner));
        _cap = capacity;
        _decimals = decimal;
        _mint(_owner, initialSupply);
        coinTokenAddress = address(this);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function _mint(address account, uint256 amount) internal override {
        super._mint(account, amount);
        _totalMinted = _totalMinted.add(amount);
    }

    function cap() public view returns (uint256) {
        return _cap;
    }

    function totalMinted() public view returns (uint256) {
        return _totalMinted;
    }

    function mintBulk(address[] memory accounts, uint256[] memory amounts)
        public
        onlyOwner
    {
        require(
            accounts.length == amounts.length,
            "SimpleERC20: lengths mismatch"
        );
        for (uint256 i = 0; i < accounts.length; i++)
            if (amounts[i] > 0) _mint(accounts[i], amounts[i]);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);

        if (from == address(0)) {
            // When minting tokens
            require(
                totalMinted().add(amount) <= cap(),
                "SimpleERC20: cap exceeded"
            );
        }
    }
}
