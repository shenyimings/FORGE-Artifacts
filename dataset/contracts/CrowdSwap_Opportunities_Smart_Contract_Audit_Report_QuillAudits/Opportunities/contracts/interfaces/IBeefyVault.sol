// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IBeefyVault is IERC20Upgradeable {
    function deposit(uint256 _amount) external;
    function withdraw(uint256 _shares) external;
}
