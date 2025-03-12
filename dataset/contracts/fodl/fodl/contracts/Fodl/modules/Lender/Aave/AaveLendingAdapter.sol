// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './Interfaces.sol';
import '../ILendingPlatform.sol';
import '../../../modules/FoldingAccount/FoldingAccountStorage.sol';
import '../../../modules/SimplePosition/SimplePositionStorage.sol';

contract AaveLendingAdapter is ILendingPlatform, SimplePositionStorage {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable PoolProvider; // IAaveLendingPoolProvider(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
    address public immutable DataProvider; // IAaveDataProvider(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d);
    address public immutable Incentives; // IAaveIncentivesController(0xd784927Ff2f95ba542BfC824c8a8a98F3495f6b5);

    uint256 private constant VARIABLE_BORROW_RATE_MODE = 2;
    uint256 private constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;

    constructor(
        address _aavePoolProvider,
        address _aaveData,
        address _aaveIncentives
    ) public {
        require(_aavePoolProvider != address(0), 'ICP0');
        require(_aaveData != address(0), 'ICP0');
        require(_aaveIncentives != address(0), 'ICP0');
        PoolProvider = _aavePoolProvider;
        DataProvider = _aaveData;
        Incentives = _aaveIncentives;
    }

    function getCollateralUsageFactor(address) external override returns (uint256) {
        address aave = IAaveLendingPoolProvider(PoolProvider).getLendingPool();
        (, , , , , uint256 hF) = IAaveLendingPool(aave).getUserAccountData(address(this));
        return uint256(1e36) / hF;
    }

    /**
     * @dev reasoning:
     * 1) get asset reserve data, which has liquidation threshold encoded in bits 16-31
     * 2) right shift the number so that we remove bits 0-15
     * 3) now with modulo 2**16, the retrieved value is the first 16 bits of the data, which is the liquiditation
     * threshold for the asset according to "struct ReserveConfigurationMap" (see Interfaces.sol).
     * This number goes from 0 (0%) to 10000 (100%). To transform it to mantissa 18, this number is multiplied by 1e14.
     **/
    function getCollateralFactorForAsset(address, address asset) external override returns (uint256 collateralFactor) {
        return
            ((IAaveLendingPool(IAaveLendingPoolProvider(PoolProvider).getLendingPool())
                .getReserveData(asset)
                .configuration
                .data >> 16) % (2**16)) * 1e14;
    }

    /**
     * @dev reasoning:
     * Aave reference prices do not take into account the number of decimals of the token, but our system does.
     * To take them into account, we multiply by ETH's decimals (1e18) and divide by the token 's decimals.
     **/
    function getReferencePrice(address, address token) public override returns (uint256) {
        return
            IAavePriceOracleGetter(IAaveLendingPoolProvider(PoolProvider).getPriceOracle())
                .getAssetPrice(token)
                .mul(1e18)
                .div(10**uint256(ERC20(token).decimals()));
    }

    function getBorrowBalance(address, address token) external override returns (uint256 borrowBalance) {
        (, , borrowBalance, , , , , , ) = IAaveDataProvider(DataProvider).getUserReserveData(token, address(this));
    }

    function getSupplyBalance(address, address token) external override returns (uint256 supplyBalance) {
        (supplyBalance, , , , , , , , ) = IAaveDataProvider(DataProvider).getUserReserveData(token, address(this));
    }

    function claimRewards(address) public override returns (address rewardsToken, uint256 rewardsAmount) {
        rewardsToken = IAaveIncentivesController(Incentives).REWARD_TOKEN();
        uint256 before = IERC20(rewardsToken).balanceOf(address(this));

        address[] memory assets = new address[](2);
        (assets[0], , ) = IAaveDataProvider(DataProvider).getReserveTokensAddresses(simplePositionStore().supplyToken);
        (, , assets[1]) = IAaveDataProvider(DataProvider).getReserveTokensAddresses(simplePositionStore().borrowToken);

        IAaveIncentivesController(Incentives).claimRewards(assets, type(uint256).max, address(this));
        rewardsAmount = IERC20(rewardsToken).balanceOf(address(this)).sub(before);
    }

    /// @dev Empty because this is done by default in Aave
    function enterMarkets(address, address[] memory markets) external override {}

    function supply(
        address,
        address token,
        uint256 amount
    ) external override {
        address aave = IAaveLendingPoolProvider(PoolProvider).getLendingPool();
        IERC20(token).safeIncreaseAllowance(aave, amount);
        IAaveLendingPool(aave).deposit(token, amount, address(this), 0);
    }

    function borrow(
        address,
        address token,
        uint256 amount
    ) external override {
        address aave = IAaveLendingPoolProvider(PoolProvider).getLendingPool();
        IAaveLendingPool(aave).borrow(token, amount, VARIABLE_BORROW_RATE_MODE, 0, address(this));
    }

    function redeemSupply(
        address,
        address token,
        uint256 amount
    ) external override {
        address aave = IAaveLendingPoolProvider(PoolProvider).getLendingPool();
        IAaveLendingPool(aave).withdraw(token, amount, address(this));
    }

    function repayBorrow(
        address,
        address token,
        uint256 amount
    ) external override {
        address aave = IAaveLendingPoolProvider(PoolProvider).getLendingPool();
        IERC20(token).safeIncreaseAllowance(address(aave), amount);
        IAaveLendingPool(aave).repay(token, amount, VARIABLE_BORROW_RATE_MODE, address(this));
    }

    /// @dev Aave uses ray precision for APRs (i.e. 1e27) while we use 1e18
    function convertFromRayToE18(uint256 factorRay) private pure returns (uint256 factorE18) {
        factorE18 = factorRay / 1e9;
    }

    /// @dev Aave uses E4 precision for factors while we use 1e18
    function convertFromE4ToE18(uint256 factorE4) private pure returns (uint256 factorE18) {
        factorE18 = factorE4.mul(1e14);
    }

    struct AssetDetails {
        uint256 ltv;
        uint256 liquidationThreshold;
        uint256 availableLiquidity;
        uint256 totalStableDebt;
        uint256 totalVariableDebt;
        uint256 liquidityRate;
        uint256 variableBorrowRate;
        uint256 supplyEmissionPerSec;
        uint256 borrowEmissionPerSec;
        bool borrowingEnabled;
        bool isActive;
        bool isFrozen;
    }

    function getAssetDetails(address asset) private view returns (AssetDetails memory assetDetails) {
        (
            ,
            assetDetails.ltv,
            assetDetails.liquidationThreshold,
            ,
            ,
            ,
            assetDetails.borrowingEnabled,
            ,
            assetDetails.isActive,
            assetDetails.isFrozen
        ) = IAaveDataProvider(DataProvider).getReserveConfigurationData(asset);

        (
            assetDetails.availableLiquidity,
            assetDetails.totalStableDebt,
            assetDetails.totalVariableDebt,
            assetDetails.liquidityRate,
            assetDetails.variableBorrowRate,
            ,
            ,
            ,
            ,

        ) = IAaveDataProvider(DataProvider).getReserveData(asset);

        (address aTokenAddress, , address vDebtTokenAddress) = IAaveDataProvider(DataProvider)
            .getReserveTokensAddresses(asset);

        (, assetDetails.supplyEmissionPerSec, ) = IAaveIncentivesController(Incentives).getAssetData(aTokenAddress);
        (, assetDetails.borrowEmissionPerSec, ) = IAaveIncentivesController(Incentives).getAssetData(vDebtTokenAddress);
    }

    function getAssetMetadata(address, address asset) external override returns (AssetMetadata memory assetMetadata) {
        AssetDetails memory data = getAssetDetails(asset);

        assetMetadata.assetAddress = asset;
        assetMetadata.assetSymbol = ERC20(asset).symbol();
        assetMetadata.assetDecimals = ERC20(asset).decimals();
        assetMetadata.referencePrice = getReferencePrice(address(0), asset);
        assetMetadata.totalLiquidity = data.availableLiquidity;
        assetMetadata.totalBorrow = data.totalStableDebt.add(data.totalVariableDebt);
        assetMetadata.totalSupply = assetMetadata.totalBorrow.add(assetMetadata.totalLiquidity);
        assetMetadata.totalReserves = 0; // Aave reserves are not relevant towards computation
        assetMetadata.supplyAPR = convertFromRayToE18(data.liquidityRate);
        assetMetadata.borrowAPR = convertFromRayToE18(data.variableBorrowRate);
        assetMetadata.rewardTokenAddress = IAaveIncentivesController(Incentives).REWARD_TOKEN();
        assetMetadata.rewardTokenDecimals = ERC20(assetMetadata.rewardTokenAddress).decimals();
        assetMetadata.rewardTokenSymbol = ERC20(assetMetadata.rewardTokenAddress).symbol();
        assetMetadata.estimatedSupplyRewardsPerYear = data.supplyEmissionPerSec.mul(SECONDS_PER_YEAR);
        assetMetadata.estimatedBorrowRewardsPerYear = data.borrowEmissionPerSec.mul(SECONDS_PER_YEAR);
        assetMetadata.collateralFactor = convertFromE4ToE18(data.ltv);
        assetMetadata.liquidationFactor = convertFromE4ToE18(data.liquidationThreshold);
        assetMetadata.canSupply = data.isActive && !data.isFrozen;
        assetMetadata.canBorrow = data.isActive && data.borrowingEnabled;
    }
}
