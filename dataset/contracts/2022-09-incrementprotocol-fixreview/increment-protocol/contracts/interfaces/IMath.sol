// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

interface IMath {
    function sqrt_int(uint256 x) external view returns (uint256);

    function newton_D(uint256 ANN, uint256 gamma, uint256[2] memory x_unsorted) external view returns (uint256);

    function newton_y(uint256 ANN, uint256 gamma, uint256[2] memory x, uint256 D, uint256 i)
        external
        view
        returns (uint256);
}
