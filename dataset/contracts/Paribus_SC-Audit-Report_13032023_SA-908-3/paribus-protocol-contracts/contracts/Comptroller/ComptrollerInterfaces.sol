// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.5.17;

import "../PToken/PToken.sol";
import "../PriceOracle/PriceOracleInterface.sol";
import "./Unitroller.sol";
import "./ComptrollerStorage.sol";

contract ComptrollerCommonInterface is ComptrollerStorage {
    /// @notice Indicator that this is a Comptroller contract (for inspection)
    function isComptroller() external pure returns (bool);

    /// @notice Emitted when an admin supports a market (marketType 0 == standard assets)
    event MarketListed(address indexed pToken, uint indexed marketType, address underlying);

    /// @notice Emitted when an account enters a market
    event MarketEntered(address indexed pToken, address indexed account);

    /// @notice Emitted when an account exits a market
    event MarketExited(address indexed pToken, address indexed account);

    /// @notice Emitted when close factor is changed by admin
    event NewCloseFactor(uint oldCloseFactorMantissa, uint newCloseFactorMantissa);

    /// @notice Emitted when a collateral factor is changed by admin
    event NewCollateralFactor(address indexed pToken, uint oldCollateralFactorMantissa, uint newCollateralFactorMantissa);

    /// @notice Emitted when liquidation incentive is changed by admin
    event NewLiquidationIncentive(uint oldLiquidationIncentiveMantissa, uint newLiquidationIncentiveMantissa);

    /// @notice Emitted when price oracle is changed
    event NewPriceOracle(PriceOracleInterface oldPriceOracle, PriceOracleInterface newPriceOracle);

    /// @notice Emitted when pause guardian is changed
    event NewPauseGuardian(address oldPauseGuardian, address newPauseGuardian);

    /// @notice Emitted when an action is paused on a market or globally (pToken == 0)
    event ActionPaused(address indexed pToken, string indexed action, bool pauseState);

    /// @notice Emitted when a new borrow-side PBX speed is calculated for a market
    event PBXBorrowSpeedUpdated(PToken indexed pToken, uint newSpeed);

    /// @notice Emitted when a new supply-side PBX speed is calculated for a market
    event PBXSupplySpeedUpdated(PToken indexed pToken, uint newSpeed);

    /// @notice Emitted when a new PBX speed is set for a contributor
    event ContributorPBXSpeedUpdated(address indexed contributor, uint newSpeed);

    /// @notice Emitted when PBX is distributed to a supplier
    event DistributedSupplierPBX(PToken indexed pToken, address indexed supplier, uint compDelta, uint PBXSupplyIndex);

    /// @notice Emitted when PBX is distributed to a borrower
    event DistributedBorrowerPBX(PToken indexed pToken, address indexed borrower, uint compDelta, uint PBXBorrowIndex);

    /// @notice Emitted when borrow cap for a pToken is changed
    event NewBorrowCap(PToken indexed pToken, uint newBorrowCap);

    /// @notice Emitted when borrow cap guardian is changed
    event NewBorrowCapGuardian(address oldBorrowCapGuardian, address newBorrowCapGuardian);

    /// @notice Emitted when PBX is granted by admin
    event PBXGranted(address indexed recipient, uint amount);

    event NewPBXToken(address oldPBXToken, address newPBXToken);

    function _become(Unitroller unitroller) external;
}

contract ComptrollerPart1Interface is ComptrollerCommonInterface {
    /// @notice Indicator that this is a Comptroller contract (for inspection)
    bool public constant isComptrollerPart1 = true;

    /*** Assets You Are In ***/

    function getAssetsIn(address account) external view returns (PToken[] memory);
    function checkMembership(address account, address pToken) external view returns (bool);
    function getDepositBorrowValues(address account) external view returns (uint, uint, uint);
    function getAllMarkets() external view returns (PToken[] memory);

    /*** Admin Functions ***/

    function _setPriceOracle(PriceOracleInterface newOracle) external;
    function _setCloseFactor(uint newCloseFactorMantissa) external;
    function _setCollateralFactor(PToken pToken, uint newCollateralFactorMantissa) external returns (uint);
    function _setLiquidationIncentive(uint newLiquidationIncentiveMantissa) external;
    function _supportMarket(PToken pToken) external returns (uint);
    function _setMarketBorrowCaps(PToken[] calldata pTokens, uint[] calldata newBorrowCaps) external;
    function _setBorrowCapGuardian(address newBorrowCapGuardian) external;
    function _setPauseGuardian(address newPauseGuardian) external;
    function _setMintPaused(address pToken, bool state) external returns (bool);
    function _setMintPausedGlobal(bool state) external returns (bool);
    function _setBorrowPaused(address pToken, bool state) external returns (bool);
    function _setBorrowPausedGlobal(bool state) external returns (bool);
    function _setTransferPaused(bool state) external returns (bool);
    function _setSeizePaused(bool state) external returns (bool);
    function _setPBXToken(address newPBXTokenAddress) external;

    /*** Policy Hooks ***/

    function mintVerify(address pToken, address minter, uint mintAmount, uint mintTokens) external;
    function redeemVerify(address pToken, address redeemer, uint redeemAmount, uint redeemTokens) external;
    function borrowVerify(address pToken, address borrower, uint borrowAmount) external;
    function repayBorrowVerify(address pToken, address payer, address borrower, uint repayAmount, uint borrowerIndex) external;
    function liquidateBorrowVerify(address pTokenBorrowed, address pTokenCollateral, address liquidator, address borrower, uint repayAmount, uint seizeTokens) external;
    function seizeVerify(address pTokenCollateral, address pTokenBorrowed, address liquidator, address borrower, uint seizeTokens) external;
    function transferVerify(address pToken, address src, address dst, uint transferTokens) external;
}

contract ComptrollerPart2Interface is ComptrollerCommonInterface {
    /// @notice Indicator that this is a Comptroller contract (for inspection)
    bool public constant isComptrollerPart2 = true;

    /*** Assets You Are In ***/

    function enterMarkets(address[] calldata pTokens) external returns (uint[] memory);
    function exitMarket(address pToken) external returns (uint);

    /*** Liquidity/Liquidation Calculations ***/

    function liquidateCalculateSeizeTokens(address pTokenBorrowed, address pTokenCollateral, uint repayAmount) external view returns (uint, uint);
    function getHypotheticalAccountLiquidity(address account, address pTokenModify, uint redeemTokens, uint borrowAmount, uint redeemTokenId) external view returns (uint, uint, uint);
    function getAccountLiquidity(address account) external view returns (uint, uint, uint);
    function getCollateralBorrowValues(address account) external view returns (uint, uint, uint);

    /*** Policy Hooks ***/

    function mintAllowed(address pToken, address minter, uint mintAmount) external returns (uint);
    function redeemAllowed(address pToken, address redeemer, uint redeemTokens) external returns (uint);
    function borrowAllowed(address pToken, address borrower, uint borrowAmount) external returns (uint);
    function transferAllowed(address pToken, address src, address dst, uint transferTokens) external returns (uint);
    function repayBorrowAllowed(address pToken, address payer, address borrower, uint repayAmount) external returns (uint);
    function seizeAllowed(address pTokenCollateral, address pTokenBorrowed, address liquidator, address borrower, uint seizeTokens) external returns (uint);
    function liquidateBorrowAllowed(address pTokenBorrowed, address pTokenCollateral, address liquidator, address borrower, uint repayAmount) external returns (uint);

    /*** PBX Distribution ***/

    function updateContributorRewards(address contributor) public;
    function claimPBXReward(address holder) external;
    function claimPBXSingle(address holder, PToken[] memory pTokens) public;
    function claimPBX(address[] memory holders, PToken[] memory pTokens, bool borrowers, bool suppliers) public;

    /*** PBX Distribution Admin ***/

    function _grantPBX(address recipient, uint amount) external;
    function _setPBXSpeeds(PToken[] calldata pTokens, uint[] calldata supplySpeeds, uint[] calldata borrowSpeeds) external;
    function _setContributorPBXSpeed(address contributor, uint PBXSpeed) external;
}

contract ComptrollerInterface is ComptrollerPart1Interface, ComptrollerPart2Interface { }

