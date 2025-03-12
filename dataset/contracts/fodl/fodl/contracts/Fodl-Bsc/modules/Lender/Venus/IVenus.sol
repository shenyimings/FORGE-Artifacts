// SPDX-License-Identifier: MIT

pragma solidity 0.6;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IVComptroller {
    function oracle() external view returns (address);

    function getXVSAddress() external view returns (address);

    function enterMarkets(address[] calldata vTokens) external returns (uint256[] memory);

    function markets(address vTokenAddress)
        external
        view
        returns (
            bool isListed,
            uint256 collateralFactorMantissa,
            bool isVenus
        );

    function borrowGuardianPaused(address) external view returns (bool);

    function mintGuardianPaused(address) external view returns (bool);

    function getAccountLiquidity(address account)
        external
        view
        returns (
            uint256 err,
            uint256 liquidity,
            uint256 shortfall
        );

    function getAssetsIn(address account) external view returns (address[] memory);

    function venusSpeeds(address vToken) external view returns (uint256);

    function claimVenus(address holder) external;

    function borrowAllowed(
        address vToken,
        address borrower,
        uint256 borrowAmount
    ) external returns (uint256);
}

interface IVToken is IERC20 {
    function mint(uint256 mintAmount) external returns (uint256);

    function redeem(uint256 redeemTokens) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);

    function repayBorrow(uint256 repayAmount) external returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function borrowBalanceCurrent(address account) external returns (uint256);

    function balanceOfUnderlying(address account) external returns (uint256);

    function getAccountSnapshot(address account)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    function totalReserves() external view returns (uint256);

    function getCash() external view returns (uint256);

    function totalBorrowsCurrent() external returns (uint256);

    function supplyRatePerBlock() external view returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function accrueInterest() external returns (uint256);
}

interface IVBNB is IVToken {
    function mint() external payable;

    function repayBorrow() external payable;
}

interface IVenusPriceOracle {
    function getUnderlyingPrice(address vToken) external view returns (uint256);
}
