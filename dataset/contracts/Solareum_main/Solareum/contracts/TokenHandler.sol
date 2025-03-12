// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TokenHandler is Ownable {
    function sendTokenToOwner(address token) external onlyOwner {
        if (IERC20(token).balanceOf(address(this)) > 0) {
            IERC20(token).transfer(owner(), IERC20(token).balanceOf(address(this)));
        }
    }
}
