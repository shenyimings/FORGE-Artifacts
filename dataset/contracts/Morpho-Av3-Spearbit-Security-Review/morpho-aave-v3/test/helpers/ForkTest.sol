// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IAToken} from "src/interfaces/aave/IAToken.sol";
import {IAaveOracle} from "@aave-v3-core/interfaces/IAaveOracle.sol";
import {IACLManager} from "@aave-v3-core/interfaces/IACLManager.sol";
import {IPoolConfigurator} from "@aave-v3-core/interfaces/IPoolConfigurator.sol";
import {IPoolDataProvider} from "@aave-v3-core/interfaces/IPoolDataProvider.sol";
import {IPool, IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPool.sol";
import {IStableDebtToken} from "@aave-v3-core/interfaces/IStableDebtToken.sol";
import {IVariableDebtToken} from "@aave-v3-core/interfaces/IVariableDebtToken.sol";

import {TestConfig, TestConfigLib} from "test/helpers/TestConfigLib.sol";
import {MathUtils} from "@aave-v3-core/protocol/libraries/math/MathUtils.sol";
import {DataTypes} from "@aave-v3-core/protocol/libraries/types/DataTypes.sol";
import {Errors as AaveErrors} from "@aave-v3-core/protocol/libraries/helpers/Errors.sol";
import {ReserveConfiguration} from "@aave-v3-core/protocol/libraries/configuration/ReserveConfiguration.sol";

import {PriceOracleSentinelMock} from "test/mocks/PriceOracleSentinelMock.sol";
import {AaveOracleMock} from "test/mocks/AaveOracleMock.sol";
import {PoolAdminMock} from "test/mocks/PoolAdminMock.sol";
import "./BaseTest.sol";

contract ForkTest is BaseTest {
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using TestConfigLib for TestConfig;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    /* STRUCTS */

    struct StableDebtSupplyData {
        uint256 currPrincipalStableDebt;
        uint256 currTotalStableDebt;
        uint256 currAvgStableBorrowRate;
        uint40 stableDebtLastUpdateTimestamp;
    }

    /* STORAGE */

    address internal constant POOL_ADMIN = address(0xB055);

    string internal network;
    uint256 internal forkId;
    TestConfig internal config;

    address internal dai;
    address internal usdc;
    address internal aave;
    address internal link;
    address internal wbtc;
    address internal weth;
    address internal wNative;
    address[] internal allUnderlyings;

    IPool internal pool;
    IACLManager internal aclManager;
    IPoolConfigurator internal poolConfigurator;
    IPoolDataProvider internal poolDataProvider;
    IPoolAddressesProvider internal addressesProvider;

    address internal aclAdmin;
    AaveOracleMock internal oracle;
    PoolAdminMock internal poolAdmin;
    PriceOracleSentinelMock oracleSentinel;

    uint256 snapshotId = type(uint256).max;

    constructor() {
        _initConfig();
        _loadConfig();

        _mockPoolAdmin();
        _mockOracle();
        _mockOracleSentinel();

        _setBalances(address(this), type(uint256).max);
    }

    function setUp() public virtual {
        _label();
    }

    function _network() internal view returns (string memory) {
        try vm.envString("NETWORK") returns (string memory configNetwork) {
            return configNetwork;
        } catch {
            return "ethereum-mainnet";
        }
    }

    function _initConfig() internal returns (TestConfig storage) {
        if (bytes(config.json).length == 0) {
            string memory root = vm.projectRoot();
            string memory path = string.concat(root, "/config/", _network(), ".json");

            config.json = vm.readFile(path);
        }

        return config;
    }

    function _loadConfig() internal {
        string memory rpcAlias = config.getRpcAlias();
        Chain memory chain = getChain(rpcAlias);

        forkId = vm.createSelectFork(chain.rpcUrl, config.getForkBlockNumber());
        vm.chainId(chain.chainId);

        addressesProvider = IPoolAddressesProvider(config.getAddressesProvider());
        pool = IPool(addressesProvider.getPool());

        aclAdmin = addressesProvider.getACLAdmin();
        aclManager = IACLManager(addressesProvider.getACLManager());
        poolConfigurator = IPoolConfigurator(addressesProvider.getPoolConfigurator());
        poolDataProvider = IPoolDataProvider(addressesProvider.getPoolDataProvider());

        dai = config.getAddress("DAI");
        usdc = config.getAddress("USDC");
        aave = config.getAddress("AAVE");
        link = config.getAddress("LINK");
        wbtc = config.getAddress("WBTC");
        weth = config.getAddress("WETH");
        wNative = config.getWrappedNative();

        allUnderlyings = pool.getReservesList();
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

    function _setBalances(address user, uint256 balance) internal {
        for (uint256 i; i < allUnderlyings.length; ++i) {
            address underlying = allUnderlyings[i];

            deal(underlying, user, balance / (10 ** (18 - ERC20(underlying).decimals())));
        }
    }

    /// @dev Reverts the fork to its initial fork state.
    function _revert() internal {
        if (snapshotId < type(uint256).max) vm.revertTo(snapshotId);
        snapshotId = vm.snapshot();
    }

    /// @dev Calculates the amount accrued to AaveV3's treasury.
    function _accruedToTreasury(address underlying) internal view returns (uint256) {
        DataTypes.ReserveData memory reserve = pool.getReserveData(underlying);
        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(underlying);
        uint256 poolBorrowIndex = pool.getReserveNormalizedVariableDebt(underlying);

        StableDebtSupplyData memory vars;
        (
            vars.currPrincipalStableDebt,
            vars.currTotalStableDebt,
            vars.currAvgStableBorrowRate,
            vars.stableDebtLastUpdateTimestamp
        ) = IStableDebtToken(reserve.stableDebtTokenAddress).getSupplyData();
        uint256 scaledTotalVariableDebt = IVariableDebtToken(reserve.variableDebtTokenAddress).scaledTotalSupply();

        uint256 currTotalVariableDebt = scaledTotalVariableDebt.rayMul(poolBorrowIndex);
        uint256 prevTotalVariableDebt = scaledTotalVariableDebt.rayMul(reserve.variableBorrowIndex);
        uint256 prevTotalStableDebt = vars.currPrincipalStableDebt.rayMul(
            MathUtils.calculateCompoundedInterest(
                vars.currAvgStableBorrowRate, vars.stableDebtLastUpdateTimestamp, reserve.lastUpdateTimestamp
            )
        );

        uint256 accruedTotalDebt =
            currTotalVariableDebt + vars.currTotalStableDebt - prevTotalVariableDebt - prevTotalStableDebt;
        uint256 newAccruedToTreasury =
            accruedTotalDebt.percentMul(reserve.configuration.getReserveFactor()).rayDiv(poolSupplyIndex);

        return (reserve.accruedToTreasury + newAccruedToTreasury).rayMul(poolSupplyIndex);
    }
}
