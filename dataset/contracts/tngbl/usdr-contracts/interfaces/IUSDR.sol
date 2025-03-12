// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IUSDR is IERC20Upgradeable {
    function burn(address account, uint256 amount) external;

    function mint(address account, uint256 amount) external;

    function rebase(uint256 supplyDelta) external;
}
