// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IPriceFeed {
    function setSharePrice(address _troveManager, address _collateral, bytes4 _signature, uint64 _decimals) external;

    // --- Function ---
    function fetchPrice() external returns (uint);
}
