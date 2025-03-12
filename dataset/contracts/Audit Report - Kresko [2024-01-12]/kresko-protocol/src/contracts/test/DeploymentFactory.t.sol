// solhint-disable no-console
// solhint-disable state-visibility
// solhint-disable no-unused-import
// solhint-disable var-name-mixedcase

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {Ownable} from "@oz/access/Ownable.sol";
import {TestBase} from "kresko-lib/utils/TestBase.t.sol";
import {ShortAssert} from "kresko-lib/utils/ShortAssert.sol";
import {stdStorage, StdStorage} from "forge-std/StdStorage.sol";
import {console2} from "forge-std/console2.sol";
import {Conversions, Deploys, Proxies} from "libs/Utils.sol";
import {LogicA, LogicB} from "mocks-misc/MockLogic.sol";
import {DeploymentFactory, IDeploymentFactory, Deployment, TransparentUpgradeableProxy} from "factory/DeploymentFactory.sol";
import {KreskoAsset} from "kresko-asset/KreskoAsset.sol";
import {KreskoAssetAnchor} from "kresko-asset/KreskoAssetAnchor.sol";

bytes32 constant EIP1967_ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
bytes32 constant EIP1967_IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

contract DeploymentFactoryTest is TestBase("MNEMONIC_DEVNET") {
    using stdStorage for StdStorage;
    using ShortAssert for *;
    using Proxies for *;
    using Conversions for *;

    DeploymentFactory factory;
    address initialOwner;

    bytes32 salt = keccak256("test");
    bytes32 salt2 = keccak256("test2");

    bytes PROXY_CREATION_CODE = type(TransparentUpgradeableProxy).creationCode;

    bytes LOGIC_A_CREATION_CODE = type(LogicA).creationCode;
    bytes LOGIC_B_CREATION_CODE = type(LogicB).creationCode;

    bytes CALLDATA_LOGIC_A;
    bytes CALLDATA_LOGIC_B;

    function setUp() public pranked(0) {
        initialOwner = getAddr(0);
        factory = new DeploymentFactory(initialOwner);

        CALLDATA_LOGIC_A = abi.encodeWithSelector(LogicA.initialize.selector);
        CALLDATA_LOGIC_B = abi.encodeWithSelector(LogicB.initialize.selector, getAddr(1), 100);
    }

    function testSetup() public {
        factory.owner().eq(initialOwner);
    }

    function testCreateProxy() public pranked(0) {
        LogicA logicA = new LogicA();
        Deployment memory proxy = factory.createProxy(address(logicA), CALLDATA_LOGIC_A);
        address proxyAddr = address(proxy.proxy);

        address admin = address(uint160(uint256(vm.load(proxyAddr, EIP1967_ADMIN_SLOT))));
        admin.eq(address(factory));

        proxyAddr.notEq(address(0));
        proxy.implementation.eq(address(logicA));
        proxy.createdAt.notEq(0);
        proxy.updatedAt.eq(proxy.createdAt);
        proxy.salt.eq(bytes32(0));
        proxy.version.eq(1);

        logicA.valueUint().eq(0);
        logicA.owner().eq(address(0));

        LogicA proxyLogicA = LogicA(proxyAddr);
        proxyLogicA.valueUint().eq(42);
        proxyLogicA.owner().eq(address(factory));

        factory.isProxy(address(logicA)).eq(false);
        factory.isProxy(proxyAddr).eq(true);
        factory.getImplementation(proxyAddr).eq(address(logicA));
        factory.getDeployCount().eq(1);
        factory.getDeployments().length.eq(1);
        assertTrue(factory.getDeployments()[0].proxy == proxy.proxy);
    }

    function testCreate2Proxy() public pranked(0) {
        LogicA logicA = new LogicA();

        address expectedProxyAddress = factory.previewCreate2Proxy(address(logicA), CALLDATA_LOGIC_A, salt);
        expectedProxyAddress.notEq(address(0));

        Deployment memory proxy = factory.create2Proxy(address(logicA), CALLDATA_LOGIC_A, salt);
        address proxyAddr = address(proxy.proxy);

        address admin = address(uint160(uint256(vm.load(proxyAddr, EIP1967_ADMIN_SLOT))));
        admin.eq(address(factory));

        proxyAddr.notEq(address(0));
        proxyAddr.eq(expectedProxyAddress);
        proxy.implementation.eq(address(logicA));
        proxy.createdAt.notEq(0);
        proxy.updatedAt.eq(proxy.createdAt);
        proxy.salt.eq(salt);
        proxy.version.eq(1);

        logicA.valueUint().eq(0);
        logicA.owner().eq(address(0));

        LogicA proxyLogicA = LogicA(proxyAddr);
        proxyLogicA.valueUint().eq(42);
        proxyLogicA.owner().eq(address(factory));

        // Bookeeping
        factory.isProxy(address(logicA)).eq(false);
        factory.isProxy(proxyAddr).eq(true);
        factory.getImplementation(proxyAddr).eq(address(logicA));
        factory.getDeployCount().eq(1);
        factory.getDeployments().length.eq(1);
        assertTrue(factory.getDeployments()[0].proxy == proxy.proxy);
    }

    function testCreate3Proxy() public pranked(0) {
        LogicA logicA = new LogicA();

        address expectedSaltAddress = factory.getCreate3Address(salt);
        address expectedProxyAddress = factory.previewCreate3Proxy(salt);

        expectedSaltAddress.notEq(address(0));
        expectedProxyAddress.eq(expectedSaltAddress);

        Deployment memory proxy = factory.create3Proxy(address(logicA), CALLDATA_LOGIC_A, salt);
        address proxyAddr = address(proxy.proxy);

        address admin = address(uint160(uint256(vm.load(proxyAddr, EIP1967_ADMIN_SLOT))));
        admin.eq(address(factory));

        proxyAddr.notEq(address(0));
        proxyAddr.eq(expectedProxyAddress);
        proxy.implementation.eq(address(logicA));
        proxy.createdAt.notEq(0);
        proxy.updatedAt.eq(proxy.createdAt);
        proxy.salt.eq(salt);
        proxy.version.eq(1);

        logicA.valueUint().eq(0);
        logicA.owner().eq(address(0));

        LogicA proxyLogicA = LogicA(proxyAddr);
        proxyLogicA.valueUint().eq(42);
        /// @notice Kresko: CREATE3 msg.sender is its temporary utility contract.
        proxyLogicA.owner().notEq(address(factory));

        // Bookeeping
        factory.isProxy(address(logicA)).eq(false);
        factory.isProxy(proxyAddr).eq(true);
        factory.getImplementation(proxyAddr).eq(address(logicA));
        factory.getDeployCount().eq(1);
        factory.getDeployments().length.eq(1);
        assertTrue(factory.getDeployments()[0].proxy == proxy.proxy);
    }

    function testCreateProxyAndLogic() public pranked(0) {
        Deployment memory proxy = factory.createProxyAndLogic(LOGIC_A_CREATION_CODE, CALLDATA_LOGIC_A);
        address proxyAddr = address(proxy.proxy);

        address admin = address(uint160(uint256(vm.load(proxyAddr, EIP1967_ADMIN_SLOT))));

        admin.eq(address(factory));

        proxyAddr.notEq(address(0));

        proxy.implementation.notEq(address(0));
        proxy.createdAt.notEq(0);
        proxy.updatedAt.eq(proxy.createdAt);
        proxy.salt.eq(bytes32(0));
        proxy.version.eq(1);

        LogicA logicA = LogicA(proxy.implementation);
        logicA.valueUint().eq(0);
        logicA.owner().eq(address(0));

        LogicA proxyLogicA = LogicA(proxyAddr);
        proxyLogicA.valueUint().eq(42);
        proxyLogicA.owner().eq(address(factory));

        factory.isProxy(address(logicA)).eq(false);
        factory.isProxy(proxyAddr).eq(true);
        factory.getImplementation(proxyAddr).eq(address(logicA));
        factory.getDeployCount().eq(1);
        factory.getDeployments().length.eq(1);
        assertTrue(factory.getDeployments()[0].proxy == proxy.proxy);
    }

    function testCreateProxy2AndLogic() public pranked(0) {
        bytes32 implementationSalt = salt.add(1);

        (address expectedProxy, address expectedImplementation) = factory.previewCreate2ProxyAndLogic(
            LOGIC_A_CREATION_CODE,
            CALLDATA_LOGIC_A,
            salt
        );
        expectedProxy.notEq(address(0));
        expectedImplementation.notEq(address(0));
        expectedProxy.notEq(expectedImplementation);

        Deployment memory proxy = factory.create2ProxyAndLogic(LOGIC_A_CREATION_CODE, CALLDATA_LOGIC_A, salt);
        address proxyAddr = address(proxy.proxy);

        address admin = address(uint160(uint256(vm.load(proxyAddr, EIP1967_ADMIN_SLOT))));
        admin.eq(address(factory));

        proxyAddr.eq(expectedProxy);
        proxyAddr.eq(
            factory.getCreate2Address(
                implementationSalt.sub(1),
                abi.encodePacked(PROXY_CREATION_CODE, abi.encode(expectedImplementation, address(factory), CALLDATA_LOGIC_A))
            ),
            "proxySaltReversed"
        );

        proxy.implementation.eq(expectedImplementation);
        proxy.implementation.eq(factory.getCreate2Address(implementationSalt, LOGIC_A_CREATION_CODE), "implementationSalt");
        proxy.createdAt.notEq(0);
        proxy.updatedAt.eq(proxy.createdAt);
        proxy.salt.eq(salt);
        proxy.version.eq(1);

        LogicA logicA = LogicA(proxy.implementation);
        logicA.valueUint().eq(0);
        logicA.owner().eq(address(0));

        LogicA proxyLogicA = LogicA(proxyAddr);
        proxyLogicA.valueUint().eq(42);
        proxyLogicA.owner().eq(address(factory));

        // Bookeeping
        factory.isProxy(address(logicA)).eq(false);
        factory.isProxy(proxyAddr).eq(true);
        factory.getImplementation(proxyAddr).eq(address(logicA));
        factory.getDeployCount().eq(1);
        factory.getDeployments().length.eq(1);
        assertTrue(factory.getDeployments()[0].proxy == proxy.proxy);
    }

    function testCreate3ProxyAndLogic() public pranked(0) {
        bytes32 implementationSalt = bytes32(uint256(salt) + 1);

        (address expectedProxy, address expectedImplementation) = factory.previewCreate3ProxyAndLogic(salt);
        expectedProxy.notEq(address(0));
        expectedImplementation.notEq(address(0));
        expectedProxy.notEq(expectedImplementation);

        Deployment memory proxy = factory.create3ProxyAndLogic(LOGIC_A_CREATION_CODE, CALLDATA_LOGIC_A, salt);
        address proxyAddr = address(proxy.proxy);

        address admin = address(uint160(uint256(vm.load(proxyAddr, EIP1967_ADMIN_SLOT))));
        admin.eq(address(factory));

        proxyAddr.eq(expectedProxy);
        proxyAddr.eq(factory.getCreate3Address(bytes32(uint256(implementationSalt) - 1)), "proxySaltReversed");
        proxy.implementation.eq(expectedImplementation);
        proxy.implementation.eq(factory.getCreate3Address(implementationSalt), "implementationSalt");
        proxy.createdAt.notEq(0);
        proxy.updatedAt.eq(proxy.createdAt);
        proxy.salt.eq(salt);
        proxy.version.eq(1);

        LogicA logicA = LogicA(proxy.implementation);
        logicA.valueUint().eq(0);
        logicA.owner().eq(address(0));

        LogicA proxyLogicA = LogicA(proxyAddr);
        proxyLogicA.valueUint().eq(42);
        /// @notice Kresko: CREATE3 msg.sender is its temporary utility contract.
        proxyLogicA.owner().notEq(address(factory));

        // Bookeeping
        factory.isProxy(address(logicA)).eq(false);
        factory.isProxy(proxyAddr).eq(true);
        factory.getImplementation(proxyAddr).eq(address(logicA));
        factory.getDeployCount().eq(1);
        factory.getDeployments().length.eq(1);
        assertTrue(factory.getDeployments()[0].proxy == proxy.proxy);
    }

    function testUpgradeAndCall() public pranked(0) {
        Deployment memory proxy = factory.createProxy(
            address(new LogicA()),
            abi.encodeWithSelector(LogicA.initialize.selector)
        );

        LogicB logicB = new LogicB();
        LogicB proxyLogicB = LogicB(address(proxy.proxy));

        address newOwner = getAddr(1);
        uint256 newValue = 100;

        vm.warp(100);
        factory.upgradeAndCall(
            proxy.proxy,
            address(logicB),
            abi.encodeWithSelector(LogicB.initialize.selector, newOwner, newValue)
        );
        logicB.owner().eq(address(0));
        logicB.valueUint().eq(0);

        proxyLogicB.owner().eq(newOwner);
        proxyLogicB.valueUint().eq(newValue);

        Deployment memory upgraded = factory.getDeployment(address(proxy.proxy));
        address proxyAddr = address(upgraded.proxy);
        upgraded.implementation.notEq(proxy.implementation);
        upgraded.version.eq(2);
        upgraded.createdAt.eq(proxy.createdAt);
        upgraded.updatedAt.notEq(proxy.updatedAt);
        upgraded.index.eq(0);
        upgraded.salt.eq(0);
        assertTrue(proxy.proxy == upgraded.proxy);

        // Bookeeping
        factory.isProxy(address(logicB)).eq(false);
        factory.isProxy(proxyAddr).eq(true);
        factory.getImplementation(proxyAddr).eq(address(logicB));
        factory.getDeployCount().eq(1);
        factory.getDeployments().length.eq(1);
        assertTrue(factory.getDeployments()[0].proxy == proxy.proxy);
    }

    function testCreate2UpgradeAndCall() public pranked(0) {
        Deployment memory proxy = factory.create2ProxyAndLogic(LOGIC_A_CREATION_CODE, CALLDATA_LOGIC_A, salt);
        address newOwner = getAddr(1);
        uint256 newValue = 100;
        bytes memory _calldata = abi.encodeWithSelector(LogicB.initialize.selector, newOwner, newValue);

        (address expectedImplementation, uint256 version) = factory.previewCreate2Upgrade(proxy.proxy, LOGIC_B_CREATION_CODE);
        proxy.implementation.notEq(expectedImplementation);
        LogicB proxyLogicB = LogicB(address(proxy.proxy));

        vm.warp(100);
        Deployment memory upgraded = factory.create2UpgradeAndCall(proxy.proxy, LOGIC_B_CREATION_CODE, _calldata);
        LogicB logicB = LogicB(expectedImplementation);

        address proxyAddr = address(upgraded.proxy);
        proxyAddr.eq(
            factory.getCreate2Address(
                upgraded.salt.add(version).sub(version),
                abi.encodePacked(PROXY_CREATION_CODE, abi.encode(proxy.implementation, address(factory), CALLDATA_LOGIC_A))
            ),
            "proxySaltReversed"
        );

        logicB.owner().eq(address(0));
        logicB.valueUint().eq(0);

        proxyLogicB.owner().eq(newOwner);
        proxyLogicB.valueUint().eq(newValue);

        upgraded.implementation.notEq(proxy.implementation);
        upgraded.implementation.eq(expectedImplementation);
        upgraded.version.eq(2);
        upgraded.createdAt.eq(proxy.createdAt);
        upgraded.updatedAt.notEq(proxy.updatedAt);
        upgraded.index.eq(0);
        upgraded.salt.eq(salt);
        assertTrue(proxy.proxy == upgraded.proxy);

        // Bookeeping
        factory.isProxy(address(logicB)).eq(false);
        factory.isProxy(proxyAddr).eq(true);
        factory.getImplementation(proxyAddr).eq(address(logicB));
        factory.getDeployCount().eq(1);
        factory.getDeployments().length.eq(1);
        assertTrue(factory.getDeployments()[0].proxy == proxy.proxy);
    }

    function testCreate3UpgradeAndCall() public pranked(0) {
        Deployment memory proxy = factory.create3ProxyAndLogic(LOGIC_A_CREATION_CODE, CALLDATA_LOGIC_A, salt);

        (address expectedImplementation, uint256 version) = factory.previewCreate3Upgrade(proxy.proxy);
        proxy.implementation.notEq(expectedImplementation);

        vm.warp(100);
        Deployment memory upgraded = factory.create3UpgradeAndCall(proxy.proxy, LOGIC_B_CREATION_CODE, CALLDATA_LOGIC_B);

        LogicB logicB = LogicB(expectedImplementation);
        LogicB proxyLogicB = LogicB(address(proxy.proxy));

        address proxyAddr = address(upgraded.proxy);

        logicB.owner().eq(address(0));
        logicB.valueUint().eq(0);

        proxyLogicB.owner().eq(getAddr(1));
        proxyLogicB.valueUint().eq(100);

        upgraded.implementation.notEq(proxy.implementation);
        upgraded.implementation.eq(factory.getCreate3Address(salt.add(version)));
        upgraded.version.eq(2);
        upgraded.createdAt.eq(proxy.createdAt);
        upgraded.updatedAt.notEq(proxy.updatedAt);
        upgraded.index.eq(0);
        upgraded.salt.eq(salt);
        assertTrue(proxy.proxy == upgraded.proxy);

        // Bookeeping
        factory.isProxy(address(logicB)).eq(false);
        factory.isProxy(proxyAddr).eq(true);
        factory.getImplementation(proxyAddr).eq(address(logicB));
        factory.getDeployCount().eq(1);
        factory.getDeployments().length.eq(1);
        assertTrue(factory.getDeployments()[0].proxy == proxy.proxy);
    }

    function testBatching() public pranked(0) {
        bytes[] memory initCalls = new bytes[](3);
        initCalls[0] = abi.encodeCall(factory.createProxy, (address(new LogicA()), CALLDATA_LOGIC_A));
        initCalls[1] = abi.encodeCall(factory.create2ProxyAndLogic, (LOGIC_A_CREATION_CODE, CALLDATA_LOGIC_A, salt));
        initCalls[2] = abi.encodeCall(factory.create3ProxyAndLogic, (LOGIC_A_CREATION_CODE, CALLDATA_LOGIC_A, salt));
        Deployment[] memory proxies = factory.batch(initCalls).map(Conversions.toDeployment);

        for (uint256 i; i < proxies.length; i++) {
            Deployment memory proxy = proxies[i];
            address proxyAddr = address(proxy.proxy);

            LogicA logicA = LogicA(proxy.implementation);
            LogicA proxyLogicA = LogicA(proxyAddr);

            proxyAddr.notEq(address(0));
            proxy.implementation.notEq(address(0));

            logicA.owner().eq(address(0));
            logicA.valueUint().eq(0);

            proxyLogicA.valueUint().eq(42);
            proxy.index.eq(i);
            assertTrue(factory.getDeployments()[i].proxy == proxy.proxy);
        }
        factory.getDeployCount().eq(initCalls.length);

        address newOwner = getAddr(1);
        uint256 newValue = 101;

        bytes[] memory upgradeCalls = new bytes[](initCalls.length);
        bytes memory upgradeCalldata = abi.encodeWithSelector(LogicB.initialize.selector, newOwner, newValue);
        bytes memory upgradeCalldata3 = abi.encodeWithSelector(LogicB.initialize.selector, getAddr(2), 5000);

        upgradeCalls[0] = abi.encodeCall(
            factory.upgradeAndCallReturn,
            (proxies[0].proxy, address(new LogicB()), upgradeCalldata)
        );
        upgradeCalls[1] = abi.encodeCall(
            factory.create2UpgradeAndCall,
            (proxies[1].proxy, LOGIC_B_CREATION_CODE, upgradeCalldata)
        );
        upgradeCalls[2] = abi.encodeCall(
            factory.create3UpgradeAndCall,
            (proxies[2].proxy, LOGIC_B_CREATION_CODE, upgradeCalldata3)
        );

        vm.warp(100);
        Deployment[] memory upgradedProxies = factory.batch(upgradeCalls).map(Conversions.toDeployment);

        for (uint256 i; i < upgradedProxies.length; i++) {
            Deployment memory proxy = upgradedProxies[i];
            address proxyAddr = address(proxy.proxy);

            LogicB logicB = LogicB(proxy.implementation);
            LogicB proxyLogicB = LogicB(proxyAddr);

            proxyAddr.eq(address(proxies[i].proxy));
            proxy.implementation.notEq(proxies[i].implementation);

            logicB.owner().eq(address(0));
            logicB.valueUint().eq(0);

            if (i == 2) {
                proxyLogicB.owner().eq(getAddr(2));
                proxyLogicB.valueUint().eq(5000);
            } else {
                proxyLogicB.valueUint().eq(newValue);
                proxyLogicB.owner().eq(newOwner);
            }

            proxy.index.eq(i);
            proxy.createdAt.eq(proxies[i].createdAt);
            proxy.updatedAt.gt(proxies[i].updatedAt);
            assertTrue(factory.getDeployments()[i].proxy == proxy.proxy);
        }
        factory.getDeployCount().eq(initCalls.length);

        address newLogicA = address(new LogicA());
        vm.expectRevert();
        factory.batch(abi.encodeCall(factory.createProxy, (newLogicA, CALLDATA_LOGIC_B)).toArray());
    }

    function testDeployerPermission() public {
        address owner = getAddr(0);
        address whitelisted = getAddr(1);
        bytes memory notOwner = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, (whitelisted));

        // cant unauthorized
        vm.prank(whitelisted);
        vm.expectRevert(notOwner);
        factory.setDeployer(whitelisted, true);

        bytes[] memory deployCalls = new bytes[](3);
        deployCalls[0] = abi.encodeCall(factory.createProxy, (address(new LogicA()), CALLDATA_LOGIC_A));
        deployCalls[1] = abi.encodeCall(factory.create2ProxyAndLogic, (LOGIC_A_CREATION_CODE, CALLDATA_LOGIC_A, salt));
        deployCalls[2] = abi.encodeCall(factory.create3ProxyAndLogic, (LOGIC_A_CREATION_CODE, CALLDATA_LOGIC_A, salt));

        // cant deploy yet
        vm.prank(whitelisted);
        vm.expectRevert(notOwner);
        factory.batch(deployCalls);

        // whitelist
        vm.prank(owner);
        factory.setDeployer(whitelisted, true);

        // run deploys
        vm.prank(whitelisted);
        Deployment[] memory proxies = factory.batch(deployCalls).map(Conversions.toDeployment);
        proxies.length.eq(deployCalls.length);

        // cannot upgrade
        vm.startPrank(whitelisted);
        address upgradedLogic = address(new LogicB());
        vm.expectRevert(notOwner);
        factory.upgradeAndCall(proxies[0].proxy, upgradedLogic, CALLDATA_LOGIC_B);
        vm.expectRevert(notOwner);
        factory.create2UpgradeAndCall(proxies[1].proxy, LOGIC_B_CREATION_CODE, CALLDATA_LOGIC_B);
        vm.expectRevert(notOwner);
        factory.create3UpgradeAndCall(proxies[2].proxy, LOGIC_B_CREATION_CODE, CALLDATA_LOGIC_B);

        bytes[] memory mixedCalls = new bytes[](2);
        address newLogicA = address(new LogicA());
        mixedCalls[0] = abi.encodeCall(factory.createProxy, (newLogicA, CALLDATA_LOGIC_A));
        mixedCalls[1] = abi.encodeCall(
            factory.create2UpgradeAndCall,
            (proxies[1].proxy, LOGIC_B_CREATION_CODE, CALLDATA_LOGIC_B)
        );

        vm.expectRevert(notOwner);
        factory.batch(mixedCalls);
        vm.stopPrank();

        vm.prank(owner);
        factory.setDeployer(whitelisted, false);

        vm.prank(whitelisted);
        vm.expectRevert(notOwner);
        factory.createProxy(newLogicA, CALLDATA_LOGIC_A);

        (address implementationAddr, uint256 version) = factory.previewCreate2Upgrade(proxies[1].proxy, LOGIC_B_CREATION_CODE);
        version.notEq(0);
        implementationAddr.notEq(address(0));

        vm.startPrank(owner);
        Deployment[] memory upgraded = factory.batch(mixedCalls).map(Conversions.toDeployment);
        upgraded.length.eq(mixedCalls.length);
        upgraded[0].implementation.eq(newLogicA);
        upgraded[0].version.eq(1);
        upgraded[0].index.eq(3);

        address(upgraded[1].proxy).eq(address(proxies[1].proxy));
        upgraded[1].implementation.eq(implementationAddr);
        upgraded[1].implementation.notEq(proxies[1].implementation);
        upgraded[1].version.notEq(proxies[1].version);
        upgraded[1].version.eq(version);
        upgraded[1].index.eq(1);
        vm.stopPrank();
    }

    function testStaticBatch() public {
        address logic = address(new LogicA());

        address owner = getAddr(0);
        address expectedAddr = factory.getCreate3Address(salt);

        bytes memory createProxy = abi.encodeCall(factory.create3Proxy, (logic, CALLDATA_LOGIC_A, salt));
        bytes memory getOwner = abi.encodeCall(factory.owner, ());
        bytes memory create3Preview = abi.encodeCall(factory.getCreate3Address, (salt));

        vm.prank(getAddr(0));
        factory.createProxy(logic, CALLDATA_LOGIC_A);

        bytes[] memory validCalls = new bytes[](3);
        validCalls[0] = getOwner;
        validCalls[1] = create3Preview;
        validCalls[2] = getOwner;

        address[] memory results = factory.batchStatic(validCalls).map(Conversions.toAddr);

        results[0].eq(owner);
        results[1].eq(expectedAddr);
        results[2].eq(owner);

        bytes[] memory invalidCalls = new bytes[](3);
        validCalls[0] = getOwner;
        validCalls[1] = create3Preview;
        validCalls[2] = createProxy;

        vm.prank(owner);
        vm.expectRevert();
        factory.batchStatic(invalidCalls);
    }

    function testAccessControl() public {
        vm.startPrank(getAddr(0));
        address logicA = address(new LogicA());
        address logicB = address(new LogicB());

        Deployment memory proxy1 = factory.createProxy(logicA, CALLDATA_LOGIC_A);
        Deployment memory proxy2 = factory.create2Proxy(logicA, CALLDATA_LOGIC_A, salt2);
        Deployment memory proxy3 = factory.create3Proxy(logicA, CALLDATA_LOGIC_A, salt2);
        vm.stopPrank();

        address invalid = getAddr(2);
        bytes memory notOwner = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, (invalid));

        vm.startPrank(invalid);

        vm.expectRevert(notOwner);
        factory.createProxy(logicA, CALLDATA_LOGIC_A);
        vm.expectRevert(notOwner);
        factory.create2Proxy(logicA, CALLDATA_LOGIC_A, salt);
        vm.expectRevert(notOwner);
        factory.create3Proxy(logicA, CALLDATA_LOGIC_A, salt);

        vm.expectRevert(notOwner);
        factory.createProxyAndLogic(LOGIC_A_CREATION_CODE, CALLDATA_LOGIC_A);
        vm.expectRevert(notOwner);
        factory.create2ProxyAndLogic(LOGIC_A_CREATION_CODE, CALLDATA_LOGIC_A, bytes32("salty"));
        vm.expectRevert(notOwner);
        factory.create3ProxyAndLogic(LOGIC_A_CREATION_CODE, CALLDATA_LOGIC_A, bytes32("saltier"));

        vm.expectRevert(notOwner);
        factory.upgradeAndCall(proxy1.proxy, logicB, CALLDATA_LOGIC_B);
        vm.expectRevert(notOwner);
        factory.upgradeAndCallReturn(proxy1.proxy, logicB, CALLDATA_LOGIC_B);
        vm.expectRevert(notOwner);
        factory.create2UpgradeAndCall(proxy2.proxy, LOGIC_B_CREATION_CODE, CALLDATA_LOGIC_B);
        vm.expectRevert(notOwner);
        factory.create3UpgradeAndCall(proxy3.proxy, LOGIC_B_CREATION_CODE, CALLDATA_LOGIC_B);

        vm.stopPrank();
        vm.startPrank(getAddr(0));

        factory.createProxy(logicA, CALLDATA_LOGIC_A);
        factory.create2Proxy(logicA, CALLDATA_LOGIC_A, salt);
        factory.create3Proxy(logicA, CALLDATA_LOGIC_A, salt);

        factory.createProxyAndLogic(LOGIC_A_CREATION_CODE, CALLDATA_LOGIC_A);
        factory.create2ProxyAndLogic(LOGIC_A_CREATION_CODE, CALLDATA_LOGIC_A, bytes32("salty"));
        factory.create3ProxyAndLogic(LOGIC_A_CREATION_CODE, CALLDATA_LOGIC_A, bytes32("saltier"));

        factory.upgradeAndCall(proxy1.proxy, logicB, CALLDATA_LOGIC_B);
        factory.upgradeAndCallReturn(proxy1.proxy, logicB, CALLDATA_LOGIC_B);
        factory.create2UpgradeAndCall(proxy2.proxy, LOGIC_B_CREATION_CODE, CALLDATA_LOGIC_B);
        factory.create3UpgradeAndCall(proxy3.proxy, LOGIC_B_CREATION_CODE, CALLDATA_LOGIC_B);

        vm.stopPrank();
    }

    function testDeployKrAssetAndAnchor() public pranked(0) {
        address kresko = 0x7366d18831e535f3Ab0b804C01d454DaD72B4c36;
        address feeRecipient = 0xC4489F3A82079C5a7b0b610Fc85952B6E585E697;
        address admin = 0xFcbB93547B7C1936fEbfe56b4cEeD9Ab66dA1857;

        bytes memory krAssetImpl = type(KreskoAsset).creationCode;
        bytes memory krAssetInitializer = abi.encodeWithSelector(
            KreskoAsset.initialize.selector,
            "Ether",
            "krETH",
            18,
            admin,
            kresko,
            address(0),
            feeRecipient,
            0,
            0
        );

        bytes32 krAssetSalt = 0x6b72455448616b72455448000000000000000000000000000000000000000000;
        bytes32 anchorSalt = 0x616b724554486b72455448000000000000000000000000000000000000000000;

        (address predictedAddress, address predictedImpl) = factory.previewCreate2ProxyAndLogic(
            krAssetImpl,
            krAssetInitializer,
            krAssetSalt
        );

        bytes memory anchorImpl = abi.encodePacked(type(KreskoAssetAnchor).creationCode, abi.encode(predictedAddress));
        bytes memory anchorInitializer = abi.encodeWithSelector(
            KreskoAssetAnchor.initialize.selector,
            predictedAddress,
            "Kresko Asset Anchor: Ether",
            "akrETH",
            admin
        );

        (address predictedAnchorAddress, address predictedAnchorImpl) = factory.previewCreate2ProxyAndLogic(
            anchorImpl,
            anchorInitializer,
            anchorSalt
        );

        bytes[] memory assets = new bytes[](2);
        assets[0] = abi.encodeCall(factory.create2ProxyAndLogic, (krAssetImpl, krAssetInitializer, krAssetSalt));
        assets[1] = abi.encodeCall(factory.create2ProxyAndLogic, (anchorImpl, anchorInitializer, anchorSalt));

        Deployment[] memory proxies = factory.batch(assets).map(Conversions.toDeployment);
        Deployment memory krAsset = proxies[0];
        Deployment memory anchor = proxies[1];

        address(krAsset.proxy).eq(predictedAddress);
        address(anchor.proxy).eq(predictedAnchorAddress);
        krAsset.implementation.eq(predictedImpl);
        anchor.implementation.eq(predictedAnchorImpl);
    }

    function _toArray(bytes memory call) internal pure returns (bytes[] memory calls) {
        calls = new bytes[](1);
        calls[0] = call;
    }
}
