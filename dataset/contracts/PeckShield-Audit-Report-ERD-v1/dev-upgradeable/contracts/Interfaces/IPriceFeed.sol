// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IPriceFeed {
    // --- Events ---
    // event LastGoodPriceUpdated(uint256 _lastGoodPrice);

    // --- Function ---
    function fetchPrice() external returns (uint256);
    function fetchPrice_view() external view returns (uint256);
}
