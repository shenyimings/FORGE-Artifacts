// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILitlabGamesToken is IERC20 {
    function burn(uint256 _amount) external;
}
