// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {IMorpho} from "src/interfaces/IMorpho.sol";
import {IPositionsManager} from "src/interfaces/IPositionsManager.sol";
import {IPool, IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPool.sol";
import {IPoolDataProvider} from "@aave-v3-core/interfaces/IPoolDataProvider.sol";
import {IAToken} from "@aave-v3-core/interfaces/IAToken.sol";

import {Types} from "src/libraries/Types.sol";
import {ERC20, SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

import {Morpho} from "src/Morpho.sol";
import {PositionsManager} from "src/PositionsManager.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {Configured, ConfigLib, Config} from "config/Configured.sol";
import "@forge-std/Script.sol";
import "@forge-std/Test.sol";

interface IDeployer {
    function performCreate2(uint256 value, bytes memory deploymentData, bytes32 salt, address owner)
        external
        returns (address newContract);
}

contract EthEModeDeploy is Script, Test, Configured {
    using ConfigLib for Config;
    using SafeTransferLib for ERC20;

    uint8 internal constant E_MODE_CATEGORY_ID = 1; // ETH e-mode.
    uint128 internal constant MAX_ITERATIONS = 4;
    uint256 internal constant DUST = 1_000;
    IDeployer internal constant DEPLOYER = IDeployer(0xD90bbCa6a99A53f8B26782EDB0B190A7D599C585);
    bytes32 internal constant SALT = 0x89a56b04d24a35c79d19800bd5ccf61c5f641037d5583422006c06bdba75af9b;

    address[] internal assetsToList;

    address internal wstEth;

    IMorpho internal morpho;
    IPositionsManager internal positionsManager;
    IPool internal pool;
    IPoolAddressesProvider internal addressesProvider;
    IPoolDataProvider internal poolDataProvider;

    ProxyAdmin internal proxyAdmin;

    IMorpho internal morphoImpl;
    address internal morphoProxy;

    function run() external {
        _initConfig();
        _loadConfig();

        vm.startBroadcast(vm.envAddress("DEPLOYER"));

        _deploy();
        _createMarkets();
        _sendUnderlyings();
        _sendATokens();
        _setAssetsAsCollateral();
        _disableSupplyOnlyAndBorrow();

        // Pause Rewards as there is no rewards on Aave V3 Mainnet.
        morpho.setIsClaimRewardsPaused(true);

        vm.stopBroadcast();

        _checkAssertions();
    }

    function _network() internal pure virtual override returns (string memory) {
        return "ethereum-mainnet";
    }

    function _loadConfig() internal virtual override {
        super._loadConfig();

        addressesProvider = IPoolAddressesProvider(config.getAddressesProvider());
        pool = IPool(addressesProvider.getPool());
        poolDataProvider = IPoolDataProvider(addressesProvider.getPoolDataProvider());

        wstEth = config.getAddress("wstETH");

        assetsToList = [weth, wstEth, dai, usdc, wbtc];
    }

    function _deploy() internal {
        positionsManager = new PositionsManager();
        morphoImpl = new Morpho();

        proxyAdmin = new ProxyAdmin();

        bytes memory input = abi.encode(
            payable(address(morphoImpl)),
            address(proxyAdmin),
            abi.encodeWithSelector(
                morphoImpl.initialize.selector,
                address(addressesProvider),
                E_MODE_CATEGORY_ID,
                address(positionsManager),
                Types.Iterations({repay: MAX_ITERATIONS, withdraw: MAX_ITERATIONS})
            )
        );
        bytes memory bytecode = type(TransparentUpgradeableProxy).creationCode;
        bytes memory deploymentData = abi.encodePacked(bytecode, input);

        morphoProxy = DEPLOYER.performCreate2(0, deploymentData, SALT, vm.envAddress("DEPLOYER"));

        Ownable2StepUpgradeable(morphoProxy).acceptOwnership();
        console2.log("Morpho Proxy Address: ", morphoProxy);
        morpho = Morpho(payable(morphoProxy));
    }

    function _createMarkets() internal {
        morpho.createMarket(weth, 0, 50_00);
        morpho.createMarket(wstEth, 0, 0);
        morpho.createMarket(dai, 0, 0);
        morpho.createMarket(usdc, 0, 0);
        morpho.createMarket(wbtc, 0, 0);
    }

    function _sendUnderlyings() internal {
        ERC20(weth).safeTransfer(address(morpho), DUST);
        ERC20(wstEth).safeTransfer(address(morpho), DUST);
        ERC20(dai).safeTransfer(address(morpho), DUST);
        ERC20(usdc).safeTransfer(address(morpho), DUST);
        ERC20(wbtc).safeTransfer(address(morpho), DUST);
    }

    function _sendATokens() internal {
        IPoolDataProvider.TokenData[] memory aTokens = poolDataProvider.getAllATokens();

        // Send aTokens to Morpho contract.
        for (uint256 i; i < aTokens.length; ++i) {
            address aToken = aTokens[i].tokenAddress;
            ERC20(aToken).safeTransfer(address(morpho), DUST);
            morpho.setAssetIsCollateralOnPool(IAToken(aToken).UNDERLYING_ASSET_ADDRESS(), false);
        }
    }

    function _setAssetsAsCollateral() internal {
        for (uint256 i; i < assetsToList.length; ++i) {
            address underlying = assetsToList[i];
            morpho.setAssetIsCollateralOnPool(underlying, true);
            morpho.setAssetIsCollateral(underlying, true);
        }
    }

    function _disableSupplyOnlyAndBorrow() internal {
        morpho.setIsSupplyPaused(wstEth, true);
        morpho.setIsSupplyPaused(dai, true);
        morpho.setIsSupplyPaused(usdc, true);
        morpho.setIsSupplyPaused(wbtc, true);

        morpho.setIsBorrowPaused(wstEth, true);
        morpho.setIsBorrowPaused(dai, true);
        morpho.setIsBorrowPaused(usdc, true);
        morpho.setIsBorrowPaused(wbtc, true);
    }

    function _checkAssertions() internal {
        assertEq(pool.getUserEMode(address(morpho)), E_MODE_CATEGORY_ID);

        assertFalse(morpho.market(weth).pauseStatuses.isSupplyPaused);
        assertFalse(morpho.market(weth).pauseStatuses.isBorrowPaused);
        assertTrue(morpho.market(weth).isCollateral);

        assertTrue(morpho.market(wstEth).pauseStatuses.isSupplyPaused);
        assertTrue(morpho.market(wstEth).pauseStatuses.isBorrowPaused);
        assertTrue(morpho.market(wstEth).isCollateral);

        assertTrue(morpho.market(dai).pauseStatuses.isSupplyPaused);
        assertTrue(morpho.market(dai).pauseStatuses.isBorrowPaused);
        assertTrue(morpho.market(dai).isCollateral);

        assertTrue(morpho.market(usdc).pauseStatuses.isSupplyPaused);
        assertTrue(morpho.market(usdc).pauseStatuses.isBorrowPaused);
        assertTrue(morpho.market(usdc).isCollateral);

        assertTrue(morpho.market(wbtc).pauseStatuses.isSupplyPaused);
        assertTrue(morpho.market(wbtc).pauseStatuses.isBorrowPaused);
        assertTrue(morpho.market(wbtc).isCollateral);
    }
}
