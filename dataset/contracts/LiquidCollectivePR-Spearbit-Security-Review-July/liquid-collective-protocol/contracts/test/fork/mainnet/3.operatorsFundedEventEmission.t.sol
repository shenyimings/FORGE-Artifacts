//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../../../src/TUPProxy.sol";
import "../../../src/OperatorsRegistry.1.sol";
import {ITransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract OperatorsEventsMigrationV1ToV2 is Test {
    bool internal _skip = false;

    function setUp() external {
        try vm.envString("MAINNET_FORK_RPC_URL") returns (string memory rpcUrl) {
            vm.createSelectFork(rpcUrl, 16_748_000);
            console.log("1.operatorsMigrationV1ToV2.t.sol is active");
        } catch {
            _skip = true;
        }
    }

    modifier shouldSkip() {
        if (!_skip) {
            _;
        }
    }

    address internal constant OPERATORS_REGISTRY_MAINNET_ADDRESS = 0x1235f1b60df026B2620e48E735C422425E06b725;
    address internal constant OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS =
        0x1d1FD2d8C87Fed864708bbab84c2Da54254F5a12;

    event FundedValidatorKeys(uint256 indexed index, bytes[] publicKeys, bool deferred);

    function test_migration_allValidatorsInOneCall() external shouldSkip {
        TUPProxy orProxy = TUPProxy(payable(OPERATORS_REGISTRY_MAINNET_ADDRESS));

        OperatorsRegistryV1 newImplementation = new OperatorsRegistryV1();

        vm.prank(OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS);
        ITransparentUpgradeableProxy(address(orProxy)).upgradeToAndCall(
            address(newImplementation), abi.encodeWithSelector(OperatorsRegistryV1.initOperatorsRegistryV1_1.selector)
        );

        OperatorsRegistryV1 or = OperatorsRegistryV1(OPERATORS_REGISTRY_MAINNET_ADDRESS);

        {
            bytes[] memory operatorPublicKeys = new bytes[](5);

            operatorPublicKeys[0] =
                hex"b41d571474def176b2b4e14c53095895e8ce1b04c3376925fd910ca8c227f28ad157868a4adcd867a84ec2ff93f3aba7";
            operatorPublicKeys[1] =
                hex"a72ce057acd00a9c26814939914bb9cc32720db14ea3a0e0f9dec0a0b9f188fbc94e6a02d53baf6691a9535fce54846c";
            operatorPublicKeys[2] =
                hex"8c36e9c58e7c6d341dbaa09890391b3700b491ff5753de199c265836fde0b6af20374762ca8c9b907777bd5c322c39a6";
            operatorPublicKeys[3] =
                hex"973b85ec57f8dcd43807644144a7c3f8096bc7d2e6a61d3b6f32f85b9c3e71b27b1826537f86196bba88293a2272d83f";
            operatorPublicKeys[4] =
                hex"b59e40fd4aba16ac7e8919519ae748fb65c2f857ee8c2919893a87ab2a6aa31b8506beda079fe563ba256827bc44c33b";

            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(0, operatorPublicKeys, true);
        }

        {
            bytes[] memory operatorPublicKeys = new bytes[](1);

            operatorPublicKeys[0] =
                hex"a9bf4fc562e4986bb01718aa342b1f6f236b24fd4e46d4e543405cf1c6594b296c182df3f11299d079c67a2ae233891a";

            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(1, operatorPublicKeys, true);
        }

        {
            bytes[] memory operatorPublicKeys = new bytes[](1);

            operatorPublicKeys[0] =
                hex"92d2bc3fe96838cc790f7285e3093fcfb5aedd157b6037a2729605fb8108e58c3ea58ed56c85398da1b5c1e13c4d4a05";

            vm.expectEmit(true, true, true, true);
            emit FundedValidatorKeys(2, operatorPublicKeys, true);
        }

        or.forceFundedValidatorKeysEventEmission(100);

        vm.expectRevert(abi.encodeWithSignature("FundedKeyEventMigrationComplete()"));
        or.forceFundedValidatorKeysEventEmission(100);
    }

    function test_migration_oneValidatorPerCall() external shouldSkip {
        TUPProxy orProxy = TUPProxy(payable(OPERATORS_REGISTRY_MAINNET_ADDRESS));

        OperatorsRegistryV1 newImplementation = new OperatorsRegistryV1();

        vm.prank(OPERATORS_REGISTRY_MAINNET_PROXY_ADMIN_ADDRESS);
        ITransparentUpgradeableProxy(address(orProxy)).upgradeToAndCall(
            address(newImplementation), abi.encodeWithSelector(OperatorsRegistryV1.initOperatorsRegistryV1_1.selector)
        );

        OperatorsRegistryV1 or = OperatorsRegistryV1(OPERATORS_REGISTRY_MAINNET_ADDRESS);

        bytes[] memory operatorPublicKeys = new bytes[](1);

        operatorPublicKeys[0] =
            hex"b41d571474def176b2b4e14c53095895e8ce1b04c3376925fd910ca8c227f28ad157868a4adcd867a84ec2ff93f3aba7";
        vm.expectEmit(true, true, true, true);
        emit FundedValidatorKeys(0, operatorPublicKeys, true);
        or.forceFundedValidatorKeysEventEmission(1);

        operatorPublicKeys[0] =
            hex"a72ce057acd00a9c26814939914bb9cc32720db14ea3a0e0f9dec0a0b9f188fbc94e6a02d53baf6691a9535fce54846c";
        vm.expectEmit(true, true, true, true);
        emit FundedValidatorKeys(0, operatorPublicKeys, true);
        or.forceFundedValidatorKeysEventEmission(1);

        operatorPublicKeys[0] =
            hex"8c36e9c58e7c6d341dbaa09890391b3700b491ff5753de199c265836fde0b6af20374762ca8c9b907777bd5c322c39a6";
        vm.expectEmit(true, true, true, true);
        emit FundedValidatorKeys(0, operatorPublicKeys, true);
        or.forceFundedValidatorKeysEventEmission(1);

        operatorPublicKeys[0] =
            hex"973b85ec57f8dcd43807644144a7c3f8096bc7d2e6a61d3b6f32f85b9c3e71b27b1826537f86196bba88293a2272d83f";
        vm.expectEmit(true, true, true, true);
        emit FundedValidatorKeys(0, operatorPublicKeys, true);
        or.forceFundedValidatorKeysEventEmission(1);

        operatorPublicKeys[0] =
            hex"b59e40fd4aba16ac7e8919519ae748fb65c2f857ee8c2919893a87ab2a6aa31b8506beda079fe563ba256827bc44c33b";
        vm.expectEmit(true, true, true, true);
        emit FundedValidatorKeys(0, operatorPublicKeys, true);
        or.forceFundedValidatorKeysEventEmission(1);

        operatorPublicKeys[0] =
            hex"a9bf4fc562e4986bb01718aa342b1f6f236b24fd4e46d4e543405cf1c6594b296c182df3f11299d079c67a2ae233891a";
        vm.expectEmit(true, true, true, true);
        emit FundedValidatorKeys(1, operatorPublicKeys, true);
        or.forceFundedValidatorKeysEventEmission(1);

        operatorPublicKeys[0] =
            hex"92d2bc3fe96838cc790f7285e3093fcfb5aedd157b6037a2729605fb8108e58c3ea58ed56c85398da1b5c1e13c4d4a05";
        vm.expectEmit(true, true, true, true);
        emit FundedValidatorKeys(2, operatorPublicKeys, true);
        or.forceFundedValidatorKeysEventEmission(1);

        vm.expectRevert(abi.encodeWithSignature("FundedKeyEventMigrationComplete()"));
        or.forceFundedValidatorKeysEventEmission(1);
    }
}
