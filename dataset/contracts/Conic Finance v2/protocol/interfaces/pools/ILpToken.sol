// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ILpToken is IERC20Metadata {
    function mint(address account, uint256 amount, address ubo) external returns (uint256);

    function burn(address _owner, uint256 _amount, address ubo) external returns (uint256);

    function taint(address from, address to) external;
}
