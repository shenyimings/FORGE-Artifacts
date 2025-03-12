pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ActionsMock {
    function approveToken(
        address token,
        address to,
        uint256 amount
    ) external {
        IERC20(token).approve(to, amount);
    }
}
