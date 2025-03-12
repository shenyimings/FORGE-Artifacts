// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IOpenSkyDutchAuctionPriceOracle {
    function getPrice(uint256 loanAmount, uint256 startTime) external view returns (uint256);
}
