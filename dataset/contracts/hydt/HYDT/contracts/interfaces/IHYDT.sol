// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.19;

import "./IERC20.sol";

interface IHYDT is IERC20 {

    function mint(address to, uint256 amount) external returns (bool);

    function burn(uint256 amount) external returns (bool);

    function burnFrom(address from, uint256 amount) external returns (bool);
}