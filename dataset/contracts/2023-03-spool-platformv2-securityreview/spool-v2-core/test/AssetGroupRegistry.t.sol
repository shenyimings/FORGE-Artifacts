// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/access/Roles.sol";
import "../src/access/SpoolAccessControl.sol";
import "../src/managers/AssetGroupRegistry.sol";
import "./libraries/Arrays.sol";
import "./mocks/MockToken.sol";

contract AssetGroupRegistryTest is Test {
    event TokenAllowed(address indexed token);
    event AssetGroupRegistered(uint256 indexed assetGroupId);

    address spoolAdmin;
    address user;

    AssetGroupRegistry private assetGroupRegistry;

    SpoolAccessControl private accessControl;

    IERC20 private tokenA;
    IERC20 private tokenB;
    IERC20 private tokenC;

    function setUp() public {
        spoolAdmin = address(0xa);
        user = address(0xb);

        address[] memory assetGroup = Arrays.sort(
            Arrays.toArray(
                address(new MockToken("Token", "T")),
                address(new MockToken("Token", "T")),
                address(new MockToken("Token", "T"))
            )
        );
        tokenA = MockToken(assetGroup[0]);
        tokenB = MockToken(assetGroup[1]);
        tokenC = MockToken(assetGroup[2]);

        vm.startPrank(spoolAdmin);
        accessControl = new SpoolAccessControl();
        accessControl.initialize();
        vm.stopPrank();

        assetGroupRegistry = new AssetGroupRegistry(accessControl);
        assetGroupRegistry.initialize(Arrays.toArray(address(tokenA), address(tokenB)));
    }

    function test_constructor_shouldSetAllowedTokens() public {
        AssetGroupRegistry anotherAssetGroupRegistry = new AssetGroupRegistry(accessControl);
        anotherAssetGroupRegistry.initialize(Arrays.toArray(address(tokenA), address(tokenB)));

        assertTrue(anotherAssetGroupRegistry.isTokenAllowed(address(tokenA)));
        assertTrue(anotherAssetGroupRegistry.isTokenAllowed(address(tokenB)));
        assertFalse(anotherAssetGroupRegistry.isTokenAllowed(address(tokenC)));
    }

    function test_constructor_shouldEmitTokenAllowedEvents() public {
        AssetGroupRegistry registry = new AssetGroupRegistry(accessControl);
        vm.expectEmit(true, true, true, true);
        emit TokenAllowed(address(tokenA));
        vm.expectEmit(true, true, true, true);
        emit TokenAllowed(address(tokenB));
        registry.initialize(Arrays.toArray(address(tokenA), address(tokenB)));
    }

    function test_allowToken_shouldAllowToken() public {
        assertFalse(assetGroupRegistry.isTokenAllowed(address(tokenC)));

        vm.prank(spoolAdmin);
        assetGroupRegistry.allowToken(address(tokenC));

        assertTrue(assetGroupRegistry.isTokenAllowed(address(tokenC)));
    }

    function test_allowToken_shouldEmitTokenAllowedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit TokenAllowed(address(tokenC));

        vm.prank(spoolAdmin);
        assetGroupRegistry.allowToken(address(tokenC));
    }

    function test_allowToken_shouldRevertWhenCalledByWrongActor() public {
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_SPOOL_ADMIN, user));

        vm.prank(user);
        assetGroupRegistry.allowToken(address(tokenC));
    }

    function test_registerAssetGroup_shouldRegisterAssetGroup() public {
        address[] memory assetGroup = Arrays.toArray(address(tokenA), address(tokenB));

        vm.prank(spoolAdmin);
        uint256 assetGroupId = assetGroupRegistry.registerAssetGroup(assetGroup);

        assertEq(assetGroupId, 1);
        assertEq(assetGroupRegistry.numberOfAssetGroups(), 1);
        assertEq(assetGroupRegistry.listAssetGroup(assetGroupId), assetGroup);
    }

    function test_registerAssetGroup_shouldRevertWhenNoAssetsAreProvided() public {
        address[] memory assetGroup = new address[](0);

        vm.expectRevert(NoAssetsProvided.selector);
        vm.prank(spoolAdmin);
        assetGroupRegistry.registerAssetGroup(assetGroup);
    }

    function test_registerAssetGroup_shouldRevertWhenProvidedAssetIsNotAllowed() public {
        address[] memory assetGroup = Arrays.toArray(address(tokenA), address(tokenB), address(tokenC));

        vm.expectRevert(abi.encodeWithSelector(TokenNotAllowed.selector, tokenC));
        vm.prank(spoolAdmin);
        assetGroupRegistry.registerAssetGroup(assetGroup);
    }

    function test_registerAssetGroup_shouldRevertWhenCalledByWrongActor() public {
        address[] memory assetGroup = Arrays.toArray(address(tokenA), address(tokenB));

        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_SPOOL_ADMIN, user));
        vm.prank(user);
        assetGroupRegistry.registerAssetGroup(assetGroup);
    }

    function test_registerAssetGroup_shouldRevertWhenAssetGroupIsAlreadyRegistered() public {
        address[] memory assetGroup = Arrays.toArray(address(tokenA), address(tokenB));

        vm.prank(spoolAdmin);
        uint256 assetGroupId = assetGroupRegistry.registerAssetGroup(assetGroup);

        vm.expectRevert(abi.encodeWithSelector(AssetGroupAlreadyExists.selector, assetGroupId));
        vm.prank(spoolAdmin);
        assetGroupRegistry.registerAssetGroup(assetGroup);
    }

    function test_registerAssetGroup_shouldEmitAssetGroupRegisteredEvent() public {
        address[] memory assetGroup = Arrays.toArray(address(tokenA), address(tokenB));

        vm.expectEmit(true, true, true, true);
        emit AssetGroupRegistered(1);

        vm.prank(spoolAdmin);
        assetGroupRegistry.registerAssetGroup(assetGroup);
    }

    function test_registerAssetGroup_firstRegisteredAssetGroupShouldHaveIdOne() public {
        address[] memory assetGroup = Arrays.toArray(address(tokenA), address(tokenB));

        vm.prank(spoolAdmin);
        uint256 assetGroupId = assetGroupRegistry.registerAssetGroup(assetGroup);

        assertEq(assetGroupId, 1);
    }

    function test_validateAssetGroup_shouldPassForValidAssetGroup() public {
        address[] memory assetGroup = Arrays.toArray(address(tokenA), address(tokenB));

        vm.prank(spoolAdmin);
        uint256 assetGroupId = assetGroupRegistry.registerAssetGroup(assetGroup);

        assetGroupRegistry.validateAssetGroup(assetGroupId);
    }

    function test_validateAssetGroup_shouldRevertForInvalidAssetGroup() public {
        address[] memory assetGroup = Arrays.toArray(address(tokenA), address(tokenB));

        vm.prank(spoolAdmin);
        uint256 assetGroupId = assetGroupRegistry.registerAssetGroup(assetGroup);

        vm.expectRevert(abi.encodeWithSelector(InvalidAssetGroup.selector, 0));
        assetGroupRegistry.validateAssetGroup(0);
        vm.expectRevert(abi.encodeWithSelector(InvalidAssetGroup.selector, assetGroupId + 1));
        assetGroupRegistry.validateAssetGroup(assetGroupId + 1);
    }

    function test_checkAssetGroupExists_shouldReturnIdWhenAssetGroupExists() public {
        address[] memory assetGroup = Arrays.toArray(address(tokenA), address(tokenB));

        vm.prank(spoolAdmin);
        uint256 assetGroupId = assetGroupRegistry.registerAssetGroup(assetGroup);

        assertEq(assetGroupRegistry.checkAssetGroupExists(assetGroup), assetGroupId);
    }

    function test_checkAssetGroupExists_shouldReturnZeroWhenAssetGroupDoesNotExist() public {
        address[] memory assetGroup = Arrays.toArray(address(tokenA), address(tokenB));

        assertEq(assetGroupRegistry.checkAssetGroupExists(assetGroup), 0);
    }

    function test_checkAssetGroupExists_willReturnZeroWhenProvidedWithSameTokensInDifferentOrder() public {
        address[] memory assetGroup1 = Arrays.toArray(address(tokenA), address(tokenB));
        address[] memory assetGroup2 = Arrays.toArray(address(tokenB), address(tokenA));

        vm.prank(spoolAdmin);
        assetGroupRegistry.registerAssetGroup(assetGroup1);

        assertEq(assetGroupRegistry.checkAssetGroupExists(assetGroup2), 0);
    }

    function test_numberOfAssetGroups_shouldReturnZeroWhenNoAssetGroupIsRegistered() public {
        assertEq(assetGroupRegistry.numberOfAssetGroups(), 0);
    }

    function test_numberOfAssetGroups_shouldReturnNumberOfRegisteredAssetGroups() public {
        address[] memory assetGroup1 = Arrays.toArray(address(tokenA), address(tokenB));
        address[] memory assetGroup2 = Arrays.toArray(address(tokenB), address(tokenA));

        vm.prank(spoolAdmin);
        assetGroupRegistry.registerAssetGroup(assetGroup1);

        assertEq(assetGroupRegistry.numberOfAssetGroups(), 1);

        vm.prank(spoolAdmin);
        vm.expectRevert(abi.encodeWithSelector(UnsortedArray.selector));
        assetGroupRegistry.registerAssetGroup(assetGroup2);

        assertEq(assetGroupRegistry.numberOfAssetGroups(), 1);
    }

    function test_listAssetGroup_shouldListAssetGroup() public {
        address[] memory assetGroup = Arrays.toArray(address(tokenA), address(tokenB));

        vm.prank(spoolAdmin);
        uint256 assetGroupId = assetGroupRegistry.registerAssetGroup(assetGroup);

        assertEq(assetGroupRegistry.listAssetGroup(assetGroupId), assetGroup);
    }

    function test_listAssetGroup_shouldRevertForInvalidAssetGroup() public {
        address[] memory assetGroup = Arrays.toArray(address(tokenA), address(tokenB));

        vm.prank(spoolAdmin);
        uint256 assetGroupId = assetGroupRegistry.registerAssetGroup(assetGroup);

        vm.expectRevert(abi.encodeWithSelector(InvalidAssetGroup.selector, 0));
        assetGroupRegistry.listAssetGroup(0);

        vm.expectRevert(abi.encodeWithSelector(InvalidAssetGroup.selector, assetGroupId + 1));
        assetGroupRegistry.listAssetGroup(assetGroupId + 1);
    }

    function test_assetGroupLength_shouldReturnLengthOfAssetGroup() public {
        address[] memory assetGroup = Arrays.toArray(address(tokenA), address(tokenB));

        vm.prank(spoolAdmin);
        uint256 assetGroupId = assetGroupRegistry.registerAssetGroup(assetGroup);

        assertEq(assetGroupRegistry.assetGroupLength(assetGroupId), 2);
    }

    function test_assetGroupLength_shouldRevertForInvalidAssetGroup() public {
        address[] memory assetGroup = Arrays.toArray(address(tokenA), address(tokenB));

        vm.prank(spoolAdmin);
        uint256 assetGroupId = assetGroupRegistry.registerAssetGroup(assetGroup);

        vm.expectRevert(abi.encodeWithSelector(InvalidAssetGroup.selector, 0));
        assetGroupRegistry.assetGroupLength(0);

        vm.expectRevert(abi.encodeWithSelector(InvalidAssetGroup.selector, assetGroupId + 1));
        assetGroupRegistry.assetGroupLength(assetGroupId + 1);
    }
}
