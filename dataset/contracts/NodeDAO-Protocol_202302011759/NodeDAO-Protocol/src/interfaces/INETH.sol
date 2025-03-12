// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.7;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface INETH is IERC20 {
    function whiteListMint(uint256 amount, address account) external;
    function whiteListBurn(uint256 amount, address account) external;
}
