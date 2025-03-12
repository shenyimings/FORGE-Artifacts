// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

interface ITangibleERC20 {
    function approve(address who, uint256 amount) external;

    function burn(uint256 amount) external;
}
