// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

interface IMintableERC20 {
    function mint(address account, uint256 amount) external;
}
