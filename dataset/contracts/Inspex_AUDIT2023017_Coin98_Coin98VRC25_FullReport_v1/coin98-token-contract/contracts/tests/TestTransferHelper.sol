// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../vrc25/Coin98Token.sol";

contract TestTransferHelper {
    address private _token;

    constructor(address token) {
        _token = token;
    }

    function sendToken(address recipient, uint256 amount) external {
        Coin98VRC25(_token).transfer(recipient, amount);
    }

    function sendTokenWithTransferFrom(address from, address recipient, uint256 amount) external {
        Coin98VRC25(_token).transferFrom(from, recipient, amount);
    }

    function approveToken(address delegate, uint256 amount) external {
        Coin98VRC25(_token).approve(delegate, amount);
    }

    function burnToken(uint256 amount) external {
        Coin98VRC25(_token).burn(amount);
    }

    function burnTokenWithBurnFrom(address from, uint256 amount) external {
        Coin98VRC25(_token).burnFrom(from, amount);
    }
}
