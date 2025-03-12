//SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0;

interface IYESController {

    struct Market {
        bool isListed;
        mapping(address => bool) accountMembership;
    }

    event MarketListed(address lToken);
    event MarketEntered(address lToken, address account);
    event MarketExited(address lToken, address account);
    event NewCollateralFactor(uint oldCollateralFactorMantissa, uint newCollateralFactorMantissa);
    event NewLiquidationIncentive(uint oldLiquidationIncentiveMantissa, uint newLiquidationIncentiveMantissa);
    event NewPriceOracle(address oldPriceOracle, address newPriceOracle);
    event NewYESVault(address oldYESVault, address newYESVault);
    event ActionPaused(address lToken, string action, bool state);

    function isController() external returns(bool);

    function enterMarkets(address[] calldata lTokens) external returns (uint[] memory);
    function exitMarket(address lToken) external returns (uint);

    function depositAllowed(address lToken) external view returns (uint);
    function withdrawAllowed(address lToken, address withdrawer) external view returns (uint);
    function borrowAllowed(address lToken, address borrower, uint borrowAmount) external returns (uint);
    function liquidateBorrowAllowed(address lToken, address borrower) external view returns (uint);
    function seizeAllowed(address lToken) external view returns (uint);

    function repayBorrowAllowed(
        address lToken
    ) external view returns (uint);

    function transferAllowed(address lToken, address src) external view returns (uint);

    function getAccountLiquidity(address account) external view returns (uint, uint, uint, uint);
    function liquidateCalculateSeizeTokens(address lToken, uint borrowBalance) external view returns (uint, uint);

    function yesVault() external view returns (address);
    function oracle() external view returns (address);
    function borrowLimitOracle() external view returns (address);
    function allMarkets() external view returns (address[] memory);

    function collateralFactorMantissa() external view returns (uint);
    function liquidationIncentiveMantissa() external view returns (uint);
    function transferGuardianPaused() external view returns (bool);

    function markets(address lToken, address account) external view returns (bool, bool);
    function accountAssets(address account) external view returns(address[] memory);
    function mintGuardianPaused(address account) external view returns(bool);
    function borrowGuardianPaused(address account) external view returns(bool);
    function borrowCaps(address account) external view returns(uint);
    function seizeGuardianPaused() external view returns(bool);
    function borrowLimitOf(address account) external view returns(uint);
}