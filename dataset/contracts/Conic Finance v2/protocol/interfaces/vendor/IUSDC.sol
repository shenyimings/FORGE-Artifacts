// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUSDC is IERC20 {
    function configureMinter(address minter, uint256 minterAllowedAmount) external returns (bool);

    function updateMasterMinter(address newMasterMinter) external returns (bool);

    function mint(address to, uint256 amount) external returns (bool);
}
