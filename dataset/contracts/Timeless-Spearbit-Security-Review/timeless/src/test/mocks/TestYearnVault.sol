// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract TestYearnVault is ERC20 {
    ERC20 public immutable token;
    uint256 public immutable BASE_UNIT;

    constructor(ERC20 token_)
        ERC20("TestYearnVault", "yTEST", token_.decimals())
    {
        token = token_;
        BASE_UNIT = 10**token_.decimals();
    }

    function deposit(uint256 tokenAmount) public returns (uint256 shareAmount) {
        uint256 tokenBalance = token.balanceOf(address(this));
        if (tokenBalance == 0) {
            shareAmount = tokenAmount;
        } else {
            shareAmount = (tokenAmount * totalSupply) / tokenBalance;
        }
        _mint(msg.sender, shareAmount);

        token.transferFrom(msg.sender, address(this), tokenAmount);
    }

    function withdraw(uint256 sharesAmount)
        public
        returns (uint256 underlyingAmount)
    {
        underlyingAmount =
            (sharesAmount * token.balanceOf(address(this))) /
            totalSupply;
        _burn(msg.sender, sharesAmount);

        token.transfer(msg.sender, underlyingAmount);
    }

    function withdraw(uint256 sharesAmount, address recipient)
        public
        returns (uint256 underlyingAmount)
    {
        underlyingAmount =
            (sharesAmount * token.balanceOf(address(this))) /
            totalSupply;
        _burn(msg.sender, sharesAmount);

        token.transfer(recipient, underlyingAmount);
    }

    function pricePerShare() public view returns (uint256) {
        uint256 totalSupply_ = totalSupply;
        if (totalSupply_ == 0) {
            return BASE_UNIT;
        }
        return (token.balanceOf(address(this)) * BASE_UNIT) / totalSupply_;
    }
}
