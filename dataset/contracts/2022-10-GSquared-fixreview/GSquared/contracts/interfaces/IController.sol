// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.10;

interface IController {
    function gTokenTotalAssets() external view returns (uint256);
}
