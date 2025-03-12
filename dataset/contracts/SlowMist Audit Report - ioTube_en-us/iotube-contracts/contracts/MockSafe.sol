// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockSafe {
    using SafeERC20 for IERC20;
    address public safe;
    mapping(address => mapping(address => uint256)) public points;
    event DepositToSafe(address token, address recipient, uint256 amount);

    constructor(address _safe) {
        safe = _safe;
    }

    function deposit(
        IERC20 token,
        address recipient,
        uint256 amount
    ) public {
        require(amount >= 1000, "invalid amount");
        require(token.balanceOf(address(this)) >= amount, "insufficient balance");
        token.safeTransfer(safe, amount);
        points[address(token)][recipient] += amount;
        emit DepositToSafe(address(token), recipient, amount);
    }
}
