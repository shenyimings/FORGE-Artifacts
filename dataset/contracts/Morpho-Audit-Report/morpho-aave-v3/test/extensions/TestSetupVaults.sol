// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "test/helpers/IntegrationTest.sol";

import {SupplyVault} from "src/extensions/SupplyVault.sol";
import {ISupplyVault} from "src/interfaces/extensions/ISupplyVault.sol";

contract TestSetupVaults is IntegrationTest {
    using SafeTransferLib for ERC20;

    address internal constant MORPHO_DAO = 0xcBa28b38103307Ec8dA98377ffF9816C164f9AFa;
    address internal constant RECIPIENT = 0x60345417a227ad7E312eAa1B5EC5CD1Fe5E2Cdc6;

    TransparentUpgradeableProxy internal wNativeSupplyVaultProxy;

    SupplyVault internal supplyVaultImplV1;

    SupplyVault internal wNativeSupplyVault;
    SupplyVault internal daiSupplyVault;
    SupplyVault internal usdcSupplyVault;

    ERC20 internal maWrappedNativeToken;
    ERC20 internal maDai;
    ERC20 internal maUsdc;

    function setUp() public virtual override {
        super.setUp();
        morpho.setRewardsManager(_rewardsManager());
        initVaultContracts();
        setVaultContractsLabels();
    }

    function _rewardsManager() internal view virtual returns (address) {
        return address(0);
    }

    function initVaultContracts() internal {
        supplyVaultImplV1 = new SupplyVault(address(morpho));

        wNativeSupplyVaultProxy = new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "");
        wNativeSupplyVault = SupplyVault(address(wNativeSupplyVaultProxy));

        deal(wNative, address(this), 1e9);
        ERC20(wNative).safeApprove(address(wNativeSupplyVault), 1e9);
        wNativeSupplyVault.initialize(wNative, RECIPIENT, "MorphoAaveWNATIVE", "maWNATIVE", 1e9, 4);
        maWrappedNativeToken = ERC20(address(wNativeSupplyVault));

        daiSupplyVault =
            SupplyVault(address(new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")));

        deal(dai, address(this), 1e9);
        ERC20(dai).safeApprove(address(daiSupplyVault), 1e9);
        daiSupplyVault.initialize(address(dai), RECIPIENT, "MorphoAaveDAI", "maDAI", 1e9, 4);
        maDai = ERC20(address(daiSupplyVault));

        usdcSupplyVault =
            SupplyVault(address(new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")));

        deal(usdc, address(this), 1e3);
        ERC20(usdc).safeApprove(address(usdcSupplyVault), 1e3);
        usdcSupplyVault.initialize(address(usdc), RECIPIENT, "MorphoAaveUSDC", "maUSDC", 1e3, 4);
        maUsdc = ERC20(address(usdcSupplyVault));
    }

    function setVaultContractsLabels() internal {
        vm.label(address(wNativeSupplyVault), "SupplyVault (WNATIVE)");
        vm.label(address(usdcSupplyVault), "SupplyVault (USDC)");
        vm.label(address(daiSupplyVault), "SupplyVault (DAI)");
    }
}
