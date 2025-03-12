// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IAToken} from "src/interfaces/aave/IAToken.sol";
import {IAaveOracle} from "@aave-v3-core/interfaces/IAaveOracle.sol";
import {IPriceOracleGetter} from "@aave-v3-core/interfaces/IPriceOracleGetter.sol";
import {IACLManager} from "@aave-v3-core/interfaces/IACLManager.sol";
import {IPoolConfigurator} from "@aave-v3-core/interfaces/IPoolConfigurator.sol";
import {IPoolDataProvider} from "@aave-v3-core/interfaces/IPoolDataProvider.sol";
import {IPool, IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPool.sol";
import {IStableDebtToken} from "@aave-v3-core/interfaces/IStableDebtToken.sol";
import {IVariableDebtToken} from "@aave-v3-core/interfaces/IVariableDebtToken.sol";
import {IRewardsController} from "@aave-v3-periphery/rewards/interfaces/IRewardsController.sol";

import {ReserveDataLib} from "src/libraries/ReserveDataLib.sol";
import {ReserveDataTestLib} from "test/helpers/ReserveDataTestLib.sol";
import {Config, ConfigLib} from "config/ConfigLib.sol";
import {MathUtils} from "@aave-v3-core/protocol/libraries/math/MathUtils.sol";
import {DataTypes} from "@aave-v3-core/protocol/libraries/types/DataTypes.sol";
import {Errors as AaveErrors} from "@aave-v3-core/protocol/libraries/helpers/Errors.sol";
import {ReserveConfiguration} from "@aave-v3-core/protocol/libraries/configuration/ReserveConfiguration.sol";

import {PermitHash} from "@permit2/libraries/PermitHash.sol";
import {IAllowanceTransfer, AllowanceTransfer} from "@permit2/AllowanceTransfer.sol";

import {PriceOracleSentinelMock} from "test/mocks/PriceOracleSentinelMock.sol";
import {FlashBorrowerMock} from "test/mocks/FlashBorrowerMock.sol";
import {AaveOracleMock} from "test/mocks/AaveOracleMock.sol";
import {PoolAdminMock} from "test/mocks/PoolAdminMock.sol";
import {Configured} from "config/Configured.sol";
import "./BaseTest.sol";

contract ForkTest is BaseTest, Configured {
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using SafeTransferLib for ERC20;
    using ConfigLib for Config;
    using ReserveDataLib for DataTypes.ReserveData;
    using ReserveDataTestLib for DataTypes.ReserveData;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    /* STRUCTS */

    struct StableDebtSupplyData {
        uint256 currPrincipalStableDebt;
        uint256 currTotalStableDebt;
        uint256 currAvgStableBorrowRate;
        uint40 stableDebtLastUpdateTimestamp;
    }

    /* CONSTANTS */

    address internal constant POOL_ADMIN = address(0xB055);
    AllowanceTransfer internal constant PERMIT2 = AllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    /* STORAGE */

    string internal network;
    uint256 internal forkId;

    IPool internal pool;
    IACLManager internal aclManager;
    IPoolConfigurator internal poolConfigurator;
    IPoolDataProvider internal poolDataProvider;
    IRewardsController internal rewardsController;
    IPoolAddressesProvider internal addressesProvider;

    address internal morphoDao;
    address internal aclAdmin;
    address internal emissionManager;

    AaveOracleMock internal oracle;
    PoolAdminMock internal poolAdmin;
    PriceOracleSentinelMock internal oracleSentinel;
    FlashBorrowerMock internal flashBorrower;

    uint256 internal snapshotId = type(uint256).max;

    constructor() {
        _initConfig();
        _loadConfig();

        deal(address(this), type(uint128).max);
        _setBalances(address(this), type(uint96).max);

        _mockPoolAdmin();
        _mockOracle();
        _mockOracleSentinel();
        _mockFlashBorrower();
    }

    function setUp() public virtual {
        _label();
    }

    function _fork() internal virtual {
        string memory rpcUrl = vm.rpcUrl(_rpcAlias());
        uint256 forkBlockNumber = config.getForkBlockNumber();

        forkId = forkBlockNumber == 0 ? vm.createSelectFork(rpcUrl) : vm.createSelectFork(rpcUrl, forkBlockNumber);
        vm.chainId(config.getChainId());
    }

    function _loadConfig() internal virtual override {
        super._loadConfig();

        _fork();

        addressesProvider = IPoolAddressesProvider(config.getAddressesProvider());
        pool = IPool(addressesProvider.getPool());
        morphoDao = config.getMorphoDao();

        aclAdmin = addressesProvider.getACLAdmin();
        aclManager = IACLManager(addressesProvider.getACLManager());
        poolConfigurator = IPoolConfigurator(addressesProvider.getPoolConfigurator());
        poolDataProvider = IPoolDataProvider(addressesProvider.getPoolDataProvider());
        rewardsController = IRewardsController(addressesProvider.getAddress(keccak256("INCENTIVES_CONTROLLER")));
        emissionManager = rewardsController.getEmissionManager();
    }

    function _label() internal virtual {
        vm.label(address(pool), "Pool");
        vm.label(address(oracle), "PriceOracle");
        vm.label(address(addressesProvider), "AddressesProvider");

        vm.label(aclAdmin, "ACLAdmin");
        vm.label(address(aclManager), "ACLManager");
        vm.label(address(poolConfigurator), "PoolConfigurator");
        vm.label(address(poolDataProvider), "PoolDataProvider");

        for (uint256 i; i < allUnderlyings.length; ++i) {
            address underlying = allUnderlyings[i];
            string memory symbol = ERC20(underlying).symbol();

            vm.label(underlying, symbol);
        }
    }

    function _mockPoolAdmin() internal {
        poolAdmin = new PoolAdminMock(poolConfigurator);

        vm.startPrank(aclAdmin);
        aclManager.addPoolAdmin(address(poolAdmin));
        aclManager.addRiskAdmin(address(poolAdmin));
        aclManager.addEmergencyAdmin(address(poolAdmin));
        vm.stopPrank();
    }

    function _mockOracle() internal {
        oracle = new AaveOracleMock(IAaveOracle(addressesProvider.getPriceOracle()), allUnderlyings);

        vm.prank(aclAdmin);
        addressesProvider.setPriceOracle(address(oracle));
    }

    function _mockOracleSentinel() internal {
        oracleSentinel = new PriceOracleSentinelMock(address(addressesProvider));

        vm.prank(aclAdmin);
        addressesProvider.setPriceOracleSentinel(address(oracleSentinel));
    }

    function _mockFlashBorrower() internal {
        flashBorrower = new FlashBorrowerMock(address(pool));

        _setBalances(address(flashBorrower), type(uint96).max);
    }

    function _setBalances(address user, uint256 balance) internal {
        for (uint256 i; i < allUnderlyings.length; ++i) {
            address underlying = allUnderlyings[i];

            deal(underlying, user, balance / (10 ** (18 - ERC20(underlying).decimals())));
        }
    }

    function _assumeETHReceiver(address receiver) internal virtual override {
        vm.assume(receiver != weth);
        super._assumeETHReceiver(receiver);
    }

    /// @dev Avoids to revert because of AAVE token snapshots: https://github.com/aave/aave-token-v2/blob/master/contracts/token/base/GovernancePowerDelegationERC20.sol#L174
    function _deal(address underlying, address user, uint256 amount) internal {
        if (amount == 0) return;

        if (underlying == weth) deal(weth, weth.balance + amount); // Refill wrapped Ether.

        if (underlying == aave) {
            uint256 balance = ERC20(underlying).balanceOf(user);

            if (amount > balance) ERC20(underlying).safeTransfer(user, amount - balance);
            if (amount < balance) {
                vm.prank(user);
                ERC20(underlying).safeTransfer(address(this), balance - amount);
            }

            return;
        }

        deal(underlying, user, amount);
    }

    /// @dev Reverts the fork to its initial fork state.
    function _revert() internal {
        if (snapshotId < type(uint256).max) vm.revertTo(snapshotId);
        snapshotId = vm.snapshot();
    }

    /// @dev Returns the total supply used towards the supply cap.
    function _totalSupplyToCap(address underlying) internal view returns (uint256) {
        DataTypes.ReserveData memory reserve = pool.getReserveData(underlying);
        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(underlying);
        uint256 poolBorrowIndex = pool.getReserveNormalizedVariableDebt(underlying);

        return reserve.totalSupplyToCap(poolSupplyIndex, poolBorrowIndex);
    }

    /// @dev Computes the valid lower bound for ltv and lt for a given CategoryEModeId, conditions required by Aave's code.
    /// https://github.com/aave/aave-v3-core/blob/94e571f3a7465201881a59555314cd550ccfda57/contracts/protocol/pool/PoolConfigurator.sol#L369-L376
    function _getLtvLt(address underlying, uint8 eModeCategoryId)
        internal
        view
        returns (uint256 ltvBound, uint256 ltBound, uint256 ltvConfig, uint256 ltConfig)
    {
        address[] memory reserves = pool.getReservesList();
        for (uint256 i = 0; i < reserves.length; ++i) {
            DataTypes.ReserveConfigurationMap memory currentConfig = pool.getConfiguration(reserves[i]);
            if (eModeCategoryId == currentConfig.getEModeCategory() || underlying == reserves[i]) {
                ltvBound = uint16(Math.max(ltvBound, currentConfig.getLtv()));

                ltBound = uint16(Math.max(ltBound, currentConfig.getLiquidationThreshold()));

                if (underlying == reserves[i]) {
                    ltvConfig = uint16(currentConfig.getLtv());
                    ltConfig = uint16(currentConfig.getLiquidationThreshold());
                }
            }
        }
    }

    function _setEModeCategoryAsset(
        DataTypes.EModeCategory memory eModeCategory,
        address underlying,
        uint8 eModeCategoryId
    ) internal {
        poolAdmin.setEModeCategory(
            eModeCategoryId,
            eModeCategory.ltv,
            eModeCategory.liquidationThreshold,
            eModeCategory.liquidationBonus,
            address(1),
            ""
        );
        poolAdmin.setAssetEModeCategory(underlying, eModeCategoryId);
    }

    function _assumeNotUnderlying(address input) internal view {
        for (uint256 i; i < allUnderlyings.length; ++i) {
            vm.assume(input != allUnderlyings[i]);
        }
    }

    function _assumeNotLsdNative(address input) internal view {
        for (uint256 i; i < lsdNatives.length; ++i) {
            vm.assume(input != lsdNatives[i]);
        }
    }

    function _randomUnderlying(uint256 seed) internal view returns (address) {
        return allUnderlyings[seed % allUnderlyings.length];
    }

    function _randomLsdNative(uint256 seed) internal view returns (address) {
        return lsdNatives[seed % lsdNatives.length];
    }
}
