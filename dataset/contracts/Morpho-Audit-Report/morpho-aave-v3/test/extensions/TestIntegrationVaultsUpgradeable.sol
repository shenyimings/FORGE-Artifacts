// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./TestSetupVaults.sol";

contract TestIntegrationVaultsUpgradeable is TestSetupVaults {
    using WadRayMath for uint256;

    function testUpgradeSupplyVault() public {
        SupplyVault wethSupplyVaultImplV2 = new SupplyVault(address(morpho));

        vm.record();
        vm.prank(proxyAdmin.owner());
        proxyAdmin.upgrade(wNativeSupplyVaultProxy, address(wethSupplyVaultImplV2));
        (, bytes32[] memory writes) = vm.accesses(address(wNativeSupplyVault));

        // 1 write for the implemention.
        assertEq(writes.length, 1);
        address newImplem = address(
            uint160(
                uint256(
                    vm.load(
                        address(wNativeSupplyVault),
                        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1) // Implementation slot.
                    )
                )
            )
        );
        assertEq(newImplem, address(wethSupplyVaultImplV2));
    }

    function testOnlyProxyOwnerCanUpgradeSupplyVault(address caller) public {
        vm.assume(caller != proxyAdmin.owner());
        SupplyVault supplyVaultImplV2 = new SupplyVault(address(morpho));

        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgrade(wNativeSupplyVaultProxy, address(supplyVaultImplV2));

        vm.prank(proxyAdmin.owner());
        proxyAdmin.upgrade(wNativeSupplyVaultProxy, address(supplyVaultImplV2));
    }

    function testOnlyProxyOwnerCanUpgradeAndCallSupplyVault() public {
        SupplyVault wethSupplyVaultImplV2 = new SupplyVault(address(morpho));

        vm.prank(address(user));
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgradeAndCall(wNativeSupplyVaultProxy, payable(address(wethSupplyVaultImplV2)), "");

        // Revert for wrong data not wrong caller.
        vm.expectRevert("Address: low-level delegate call failed");
        proxyAdmin.upgradeAndCall(wNativeSupplyVaultProxy, payable(address(wethSupplyVaultImplV2)), "");
    }

    function testSupplyVaultImplementationsShouldBeInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        supplyVaultImplV1.initialize(address(wNative), RECIPIENT, "MorphoAaveWETH", "maWETH", 0, 4);
    }

    function testTransferOwnershipRevertsIfNotOwner(address newOwner, address caller) public {
        vm.assume(caller != wNativeSupplyVault.owner() && caller != address(proxyAdmin));
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        wNativeSupplyVault.transferOwnership(newOwner);
    }

    function testTransferOwnership(address newOwner) public {
        wNativeSupplyVault.transferOwnership(newOwner);
        assertEq(wNativeSupplyVault.pendingOwner(), newOwner);
        assertEq(wNativeSupplyVault.owner(), address(this));
    }

    function testAcceptOwnershipFailsIfNotPendingOwner(address newOwner, address wrongOwner) public {
        vm.assume(newOwner != wrongOwner);
        wNativeSupplyVault.transferOwnership(newOwner);
        vm.expectRevert("Ownable2Step: caller is not the new owner");
        vm.prank(wrongOwner);
        wNativeSupplyVault.acceptOwnership();
    }

    function testAcceptOwnership(address newOwner) public {
        wNativeSupplyVault.transferOwnership(newOwner);
        vm.prank(newOwner);
        wNativeSupplyVault.acceptOwnership();
        assertEq(wNativeSupplyVault.pendingOwner(), address(0));
        assertEq(wNativeSupplyVault.owner(), newOwner);
    }
}
