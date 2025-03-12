// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface IDrakeV0GameMaster {
    function swapAmountForCrystals(address orbAddress, uint256 crystalsAmount) external returns (uint256);
    function priceImpact(address pair, uint256 sellAmount, uint256 numerator) external view returns (uint256);
    function updateBalance(address holder, uint256 balance) external;
}