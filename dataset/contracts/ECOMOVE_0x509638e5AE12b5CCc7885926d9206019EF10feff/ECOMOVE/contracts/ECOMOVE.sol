//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract ECOMOVE is ERC20Burnable {
    address private immutable owner;

    address liquidity;

    address marketing = 0xE74a7f7724D00699d69461B64f97E3D55A77E09A;

    address reward = 0x4848D6052cA40d0C796F229f081AeC36CEF84E12;

    modifier onlyOwner() {
        require(_msgSender() == owner, "Only owner accounts");
        _;
    }

    constructor() ERC20("Ecomove", "ECM") {
        _mint(_msgSender(), 50_000_000 * 10**18);
        owner = _msgSender();
    }

    function setLiquidity(address _liquidity) external onlyOwner {
        liquidity = _liquidity;
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        uint256 marketingTax = 0;
        uint256 rewardTax = 0;
        if (liquidity == msg.sender) {
            // BUY
            marketingTax = amount / 100;
            rewardTax = amount / 100;

            _transfer(msg.sender, marketing, marketingTax);
            _transfer(msg.sender, reward, rewardTax);
        } else if (liquidity == to) {
            // SELL
            marketingTax = (amount * 2) / 100;
            rewardTax = (amount * 2) / 100;

            _transfer(msg.sender, marketing, marketingTax);
            _transfer(msg.sender, reward, rewardTax);
        }

        _transfer(msg.sender, to, amount - marketingTax - rewardTax);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        uint256 marketingTax = 0;
        uint256 rewardTax = 0;
        if (liquidity == from) {
            // BUY
            marketingTax = amount / 100;
            rewardTax = amount / 100;

            _transfer(from, marketing, marketingTax);
            _transfer(from, reward, rewardTax);
        } else if (liquidity == to) {
            // SELL
            marketingTax = (amount * 2) / 100;
            rewardTax = (amount * 2) / 100;

            _transfer(from, marketing, marketingTax);
            _transfer(from, reward, rewardTax);
        }

        address spender = _msgSender();
        _spendAllowance(from, spender, amount - marketingTax - rewardTax);
        _transfer(from, to, amount);
        return true;
    }
}
