//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

interface IERC20BM {
    function mint(address account, uint256 amount) external;

    function burn(address account, uint256 amount) external;
}
