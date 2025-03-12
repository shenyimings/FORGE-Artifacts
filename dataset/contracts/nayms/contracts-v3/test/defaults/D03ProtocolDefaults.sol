// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { D02TestSetup, console2, LibHelpers, LibConstants, LibAdmin, LibObject } from "./D02TestSetup.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Entity } from "src/diamonds/nayms/interfaces/FreeStructs.sol";

/// @notice Default test setup part 03
///         Protocol / project level defaults
///         Setup internal token IDs, entities,

contract D03ProtocolDefaults is D02TestSetup {
    bytes32 public immutable account0Id = LibHelpers._getIdForAddress(address(this));
    bytes32 public naymsTokenId;

    bytes32 public immutable systemContext = LibAdmin._getSystemId();

    bytes32 public constant DEFAULT_ACCOUNT0_ENTITY_ID = bytes32("e0");
    bytes32 public constant DEFAULT_UNDERWRITER_ENTITY_ID = bytes32("e1");
    bytes32 public constant DEFAULT_BROKER_ENTITY_ID = bytes32("e2");
    bytes32 public constant DEFAULT_CAPITAL_PROVIDER_ENTITY_ID = bytes32("e3");
    bytes32 public constant DEFAULT_INSURED_PARTY_ENTITY_ID = bytes32("e4");

    // deriving public keys from private keys
    address public immutable signer1 = vm.addr(0xACC1);
    address public immutable signer2 = vm.addr(0xACC2);
    address public immutable signer3 = vm.addr(0xACC3);
    address public immutable signer4 = vm.addr(0xACC4);

    bytes32 public immutable signer1Id = LibHelpers._getIdForAddress(vm.addr(0xACC1));
    bytes32 public immutable signer2Id = LibHelpers._getIdForAddress(vm.addr(0xACC2));
    bytes32 public immutable signer3Id = LibHelpers._getIdForAddress(vm.addr(0xACC3));
    bytes32 public immutable signer4Id = LibHelpers._getIdForAddress(vm.addr(0xACC4));

    function setUp() public virtual override {
        console2.log("\n Test SETUP:");
        super.setUp();

        console2.log("\n -- D03 Protocol Defaults\n");

        console2.log("Test contract address ID, aka account0Id:");
        console2.logBytes32(account0Id);

        naymsTokenId = LibHelpers._getIdForAddress(naymsAddress);
        console2.log("Nayms Token ID:");
        console2.logBytes32(naymsTokenId);

        vm.label(signer1, "Account 1 (Underwriter Rep)");
        vm.label(signer2, "Account 2 (Broker Rep)");
        vm.label(signer3, "Account 3 (Capital Provider Rep)");
        vm.label(signer4, "Account 4 (Insured Party Rep)");

        // vm.startPrank(msg.sender);
        nayms.addSupportedExternalToken(wethAddress);

        Entity memory entity = Entity({
            assetId: LibHelpers._getIdForAddress(wethAddress),
            collateralRatio: LibConstants.BP_FACTOR,
            maxCapacity: 100 ether,
            utilizedCapacity: 0,
            simplePolicyEnabled: true
        });

        nayms.createEntity(DEFAULT_ACCOUNT0_ENTITY_ID, account0Id, entity, "entity test hash");
        nayms.createEntity(DEFAULT_UNDERWRITER_ENTITY_ID, signer1Id, entity, "entity test hash");
        nayms.createEntity(DEFAULT_BROKER_ENTITY_ID, signer2Id, entity, "entity test hash");
        nayms.createEntity(DEFAULT_CAPITAL_PROVIDER_ENTITY_ID, signer3Id, entity, "entity test hash");
        nayms.createEntity(DEFAULT_INSURED_PARTY_ENTITY_ID, signer4Id, entity, "entity test hash");

        // transfer ownership and change system admin to be the test contract address
        // nayms.transferOwnership(address(this));
        // vm.stopPrank();

        console2.log("\n -- END TEST SETUP D03 Protocol Defaults --\n");
    }

    function createTestEntity(bytes32 adminId) internal returns (bytes32 entityId) {
        // create entity with signer2 as child
        entityId = "0xe1";
        Entity memory entity1 = initEntity(weth, 5000, 10000, 10000, false);
        nayms.createEntity(entityId, adminId, entity1, bytes32(0));
    }

    function initEntity(
        ERC20 _asset,
        uint256 _collateralRatio,
        uint256 _maxCapacity,
        uint256 _utilizedCapacity,
        bool _simplePolicyEnabled
    ) public pure returns (Entity memory e) {
        bytes32 assetId = LibHelpers._getIdForAddress(address(_asset));
        return initEntity2(assetId, _collateralRatio, _maxCapacity, _utilizedCapacity, _simplePolicyEnabled);
    }

    function initEntity2(
        bytes32 _assetId,
        uint256 _collateralRatio,
        uint256 _maxCapacity,
        uint256 _utilizedCapacity,
        bool _simplePolicyEnabled
    ) public pure returns (Entity memory e) {
        e.assetId = _assetId;
        e.collateralRatio = _collateralRatio;
        e.maxCapacity = _maxCapacity;
        e.utilizedCapacity = _utilizedCapacity;
        e.simplePolicyEnabled = _simplePolicyEnabled;
    }
}
