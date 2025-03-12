// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../../libraries/Oracle.sol";

interface IOverlayV1FeedFactory {
    // immutables
    function microWindow() external view returns (uint256);

    function macroWindow() external view returns (uint256);

    // registry of deployed feeds by factory
    function isFeed(address) external view returns (bool);
}
