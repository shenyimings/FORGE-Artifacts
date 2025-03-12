//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/utils/Context.sol';

interface ICEther is IERC20 {
    function mint() external payable;

    function mint(address to) external payable;

    function redeemUnderlying(uint256 amount) external returns (uint256);

    function supplyRatePerBlock() external view returns (uint256);

    function exchangeRateStored() external view returns (uint256);
}

contract CEther is Context, ERC20Burnable, ICEther {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint() external payable override {
        _mint(_msgSender(), msg.value);
    }

    function mint(address to) external payable override {
        _mint(to, msg.value);
    }

    function redeemUnderlying(uint256 amount) external override returns (uint256) {
        _burn(_msgSender(), amount);

        payable(_msgSender()).transfer(amount);
    }

    function supplyRatePerBlock() external view override returns (uint256) {
        return 94339312732;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function exchangeRateStored() external view override returns (uint256) {
        return 1e18;
    }
}
