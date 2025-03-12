// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../../libraries/Oracle.sol";

interface IOverlayV1Feed {
    // immutables
    function microWindow() external view returns (uint256);

    function macroWindow() external view returns (uint256);

    // returns freshest possible data from oracle
    function latest() external view returns (Oracle.Data memory);
}
