// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Mintable.sol";

contract CouponToken is ERC20, ERC20Burnable, Ownable, Mintable {
    uint256 public totalBurn = 0;

    constructor() ERC20('Foodcourt Coupon', 'COUPON') {}

    function mint(address _to, uint256 _amount) public onlyMinter {
        increaseMint(_amount);
        _mint(_to, _amount);
    }

    function burn(uint256 amount) public override {
        ERC20Burnable.burn(amount);
        totalBurn += amount;
    }

    function burnFrom(address account, uint256 amount) public override {
        ERC20Burnable.burnFrom(account, amount);
        totalBurn += amount;
    }
}
