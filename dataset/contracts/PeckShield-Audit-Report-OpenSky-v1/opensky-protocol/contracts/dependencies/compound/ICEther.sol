// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface ICEther {
    function balanceOf(address owner) external view returns (uint256);

    function balanceOfUnderlying(address owner) external returns (uint256);

    function mint() external payable;

    function redeem(uint256 amount) external returns (uint256);

    function redeemUnderlying(uint256 amount) external returns (uint256);

    function supplyRatePerBlock() external view returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function totalBorrows() external view returns (uint256);

    function totalReserves() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function getCash() external view returns (uint256);

    function accrualBlockNumber() external view returns (uint256);

    function interestRateModel() external view returns (address);

    function reserveFactorMantissa() external view returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);
}
