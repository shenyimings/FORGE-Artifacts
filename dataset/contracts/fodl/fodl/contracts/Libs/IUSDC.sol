// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

abstract contract IUSDC is ERC20 {
    function mint(address to, uint256 amount) external virtual returns (bool);

    function owner() external virtual returns (address);

    function updateMasterMinter(address _newMasterMinter) external virtual;

    function configureMinter(address minter, uint256 minterAllowedAmount) external virtual returns (bool);
}
