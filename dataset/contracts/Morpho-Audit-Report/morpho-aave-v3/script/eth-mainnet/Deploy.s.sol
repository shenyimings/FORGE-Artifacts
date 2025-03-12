// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {IMorpho} from "src/interfaces/IMorpho.sol";
import {IPositionsManager} from "src/interfaces/IPositionsManager.sol";
import {IPool, IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPool.sol";

import {Types} from "src/libraries/Types.sol";

import {Morpho} from "src/Morpho.sol";
import {PositionsManager} from "src/PositionsManager.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {Configured, ConfigLib, Config} from "config/Configured.sol";
import "@forge-std/Script.sol";

contract Deploy is Script, Configured {
    using ConfigLib for Config;

    uint8 internal constant E_MODE_CATEGORY_ID = 0;

    IMorpho internal morpho;
    IPositionsManager internal positionsManager;
    IPoolAddressesProvider internal addressesProvider;

    ProxyAdmin internal proxyAdmin;

    IMorpho internal morphoImpl;
    TransparentUpgradeableProxy internal morphoProxy;

    function run() external {
        _initConfig();
        _loadConfig();

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        _deploy();
        morpho.createMarket(dai, 3_333, 3_333);
        morpho.createMarket(usdc, 3_333, 3_333);
        morpho.createMarket(wbtc, 3_333, 3_333);
        vm.stopBroadcast();
    }

    function _network() internal pure virtual override returns (string memory) {
        return "ethereum-mainnet";
    }

    function _loadConfig() internal virtual override {
        super._loadConfig();

        addressesProvider = IPoolAddressesProvider(config.getAddressesProvider());
    }

    function _deploy() internal {
        positionsManager = new PositionsManager();
        morphoImpl = new Morpho();

        proxyAdmin = new ProxyAdmin();
        morphoProxy = new TransparentUpgradeableProxy(
            payable(address(morphoImpl)),
            address(proxyAdmin),
            abi.encodeWithSelector(
                morphoImpl.initialize.selector,
                address(addressesProvider),
                E_MODE_CATEGORY_ID,
                address(positionsManager),
                Types.Iterations({repay: 10, withdraw: 10})
            )
        );
        morpho = Morpho(payable(address(morphoProxy)));
    }
}
