// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../DataLoader.s.sol";
import "../AddressFetcher.s.sol";
import "../../contracts/yield/NativeGateway.sol";

contract NativeGatewayDeployer is DataLoader, AddressFetcher {
    NativeGateway public nativeGateway;

    // TODO: setter (like the dex and the timelock)

    function deployNativeGateway(address wrappedNativeSmartFarmooor) internal virtual {
        nativeGateway = new NativeGateway(WRAPPED_NATIVE_TOKEN, wrappedNativeSmartFarmooor);
    }

    function transferOwnershipNativeGateway(address transferTo) internal {
        nativeGateway.transferOwnership(transferTo);
    }

    function verifyNativeGateway(address owner, address wrappedNativeSmartFarmooor) internal {
        assertEq(
            address(nativeGateway) !=
            0x0000000000000000000000000000000000000000,
            true
        );
        assertEq(nativeGateway.owner(), owner);
        assertEq(nativeGateway.wrappedNativeToken(), WRAPPED_NATIVE_TOKEN);
        assertEq(nativeGateway.wrappedNativeSmartFarmooor(), wrappedNativeSmartFarmooor);
        assertEq(ISmartFarmooor(nativeGateway.wrappedNativeSmartFarmooor()).baseToken(), WRAPPED_NATIVE_TOKEN);
    }

    function printNativeGatewayStorage() internal view {
        console.log("\nNative gateway storage");
        console.log("Owner                        : ", nativeGateway.owner());
        console.log("Wrapped native token         : ", nativeGateway.wrappedNativeToken());
        console.log("Wrapped native smart farmooor: ", nativeGateway.wrappedNativeSmartFarmooor());
    }
}
