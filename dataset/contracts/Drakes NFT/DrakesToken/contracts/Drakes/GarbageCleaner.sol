//SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./SafeMath.sol";
import "./IBEP20.sol";

contract GarbageCleaner {
    using SafeMath for uint256;

    address private admin;
    constructor (address _admin) internal {
        admin = _admin;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "TokensRescuer: not authorized");
        _;
    }

    function rescueETHPool(uint256 percentage, address receiver) public virtual onlyAdmin {
        uint256 value_to_transfer = 0;
        if (percentage == 100) {
            value_to_transfer = address(this).balance;
        } else {
            value_to_transfer = address(this).balance.mul(percentage).div(100);
        }
        payable(receiver).transfer(value_to_transfer);
    }

    function rescueTokenPool(address token, address receiver) public virtual onlyAdmin {
        uint256 balance = IBEP20(token).balanceOf(address(this));
        IBEP20(token).transfer(receiver, balance);
    }
}
