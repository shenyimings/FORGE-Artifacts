// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { D03ProtocolDefaults, console2, LibConstants, LibHelpers } from "./defaults/D03ProtocolDefaults.sol";

import { InitDiamondFixture } from "./fixtures/InitDiamondFixture.sol";
import { INayms, IDiamondLoupe } from "src/diamonds/nayms/INayms.sol";

import { CREATE3 } from "solmate/utils/CREATE3.sol";

contract T01DeploymentTest is D03ProtocolDefaults {
    using stdStorage for StdStorage;

    function setUp() public virtual override {
        super.setUp();
    }

    function testOwnerOfDiamond() public {
        assertEq(nayms.owner(), account0);
    }

    // todo test against artifact data generated for deployment
    function testDiamondLoupeFunctionality() public view {
        IDiamondLoupe.Facet[] memory facets = nayms.facets();

        for (uint256 i = 0; i < facets.length; i++) {
            nayms.facetFunctionSelectors(facets[i].facetAddress);
        }

        nayms.facetAddresses();
    }

    function testFork() public {
        string memory mainnetUrl = vm.rpcUrl("mainnet");
        string memory goerliUrl = vm.rpcUrl("goerli");
        uint256 mainnetFork = vm.createSelectFork(mainnetUrl, MAINNET_FORK_BLOCK_NUMBER);
        uint256 goerliFork = vm.createSelectFork(goerliUrl, GOERLI_FORK_BLOCK_NUMBER);
    }

    function testInitDiamond() public {
        InitDiamondFixture fixture = new InitDiamondFixture();

        vm.recordLogs();

        fixture.initialize();

        // check logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        Vm.Log memory entry = entries[entries.length - 1];
        assertEq(entry.topics.length, 1);
        assertEq(entry.topics[0], keccak256("InitializeDiamond(address,bytes32)"));
        (address a, bytes32 b) = abi.decode(entry.data, (address, bytes32));
        assertEq(a, account0);
        assertEq(b, account0Id);

        // check storage

        assertEq(fixture.totalSupply(), 1_000_000_000e18);
        assertEq(fixture.balanceOf(account0), 1_000_000_000e18);

        assertTrue(fixture.isRoleInGroup(LibConstants.ROLE_SYSTEM_ADMIN, LibConstants.GROUP_SYSTEM_ADMINS));
        assertTrue(fixture.isRoleInGroup(LibConstants.ROLE_SYSTEM_ADMIN, LibConstants.GROUP_SYSTEM_MANAGERS));
        assertTrue(fixture.isRoleInGroup(LibConstants.ROLE_SYSTEM_MANAGER, LibConstants.GROUP_SYSTEM_MANAGERS));
        assertTrue(fixture.isRoleInGroup(LibConstants.ROLE_ENTITY_ADMIN, LibConstants.GROUP_ENTITY_ADMINS));
        assertTrue(fixture.isRoleInGroup(LibConstants.ROLE_ENTITY_MANAGER, LibConstants.GROUP_ENTITY_MANAGERS));
        assertTrue(fixture.isRoleInGroup(LibConstants.ROLE_BROKER, LibConstants.GROUP_BROKERS));
        assertTrue(fixture.isRoleInGroup(LibConstants.ROLE_UNDERWRITER, LibConstants.GROUP_UNDERWRITERS));
        assertTrue(fixture.isRoleInGroup(LibConstants.ROLE_INSURED_PARTY, LibConstants.GROUP_INSURED_PARTIES));
        assertTrue(fixture.isRoleInGroup(LibConstants.ROLE_CAPITAL_PROVIDER, LibConstants.GROUP_CAPITAL_PROVIDERS));
        assertTrue(fixture.isRoleInGroup(LibConstants.ROLE_CLAIMS_ADMIN, LibConstants.GROUP_CLAIMS_ADMINS));
        assertTrue(fixture.isRoleInGroup(LibConstants.ROLE_TRADER, LibConstants.GROUP_TRADERS));
        assertTrue(fixture.isRoleInGroup(LibConstants.ROLE_SEGREGATED_ACCOUNT, LibConstants.GROUP_SEGREGATED_ACCOUNTS));
        assertTrue(fixture.isRoleInGroup(LibConstants.ROLE_SERVICE_PROVIDER, LibConstants.GROUP_SERVICE_PROVIDERS));
        assertTrue(fixture.isRoleInGroup(LibConstants.ROLE_BROKER, LibConstants.GROUP_POLICY_HANDLERS));
        assertTrue(fixture.isRoleInGroup(LibConstants.ROLE_INSURED_PARTY, LibConstants.GROUP_POLICY_HANDLERS));

        assertTrue(fixture.canGroupAssignRole(LibConstants.ROLE_SYSTEM_ADMIN, LibConstants.GROUP_SYSTEM_ADMINS));
        assertTrue(fixture.canGroupAssignRole(LibConstants.ROLE_SYSTEM_MANAGER, LibConstants.GROUP_SYSTEM_MANAGERS));
        assertTrue(fixture.canGroupAssignRole(LibConstants.ROLE_ENTITY_ADMIN, LibConstants.GROUP_SYSTEM_MANAGERS));
        assertTrue(fixture.canGroupAssignRole(LibConstants.ROLE_ENTITY_MANAGER, LibConstants.GROUP_SYSTEM_MANAGERS));
        assertTrue(fixture.canGroupAssignRole(LibConstants.ROLE_BROKER, LibConstants.GROUP_SYSTEM_MANAGERS));
        assertTrue(fixture.canGroupAssignRole(LibConstants.ROLE_UNDERWRITER, LibConstants.GROUP_SYSTEM_MANAGERS));
        assertTrue(fixture.canGroupAssignRole(LibConstants.ROLE_INSURED_PARTY, LibConstants.GROUP_SYSTEM_MANAGERS));
        assertTrue(fixture.canGroupAssignRole(LibConstants.ROLE_CAPITAL_PROVIDER, LibConstants.GROUP_SYSTEM_MANAGERS));
        assertTrue(fixture.canGroupAssignRole(LibConstants.ROLE_BROKER, LibConstants.GROUP_SYSTEM_MANAGERS));
        assertTrue(fixture.canGroupAssignRole(LibConstants.ROLE_INSURED_PARTY, LibConstants.GROUP_SYSTEM_MANAGERS));
        assertTrue(fixture.canGroupAssignRole(LibConstants.ROLE_UNDERWRITER, LibConstants.GROUP_SYSTEM_MANAGERS));
        assertTrue(fixture.canGroupAssignRole(LibConstants.ROLE_CLAIMS_ADMIN, LibConstants.GROUP_SYSTEM_MANAGERS));
        assertTrue(fixture.canGroupAssignRole(LibConstants.ROLE_TRADER, LibConstants.GROUP_SYSTEM_MANAGERS));
        assertTrue(fixture.canGroupAssignRole(LibConstants.ROLE_SEGREGATED_ACCOUNT, LibConstants.GROUP_SYSTEM_MANAGERS));
        assertTrue(fixture.canGroupAssignRole(LibConstants.ROLE_SERVICE_PROVIDER, LibConstants.GROUP_SYSTEM_MANAGERS));

        assertTrue(fixture.isObject(0));
        assertTrue(fixture.isObject(account0Id));

        assertEq(fixture.getDiscountToken(), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        assertEq(fixture.getEquilibriumLevel(), 20);
        assertEq(fixture.getTargetNaymsAllocation(), 20);
        assertEq(fixture.getMaxDiscount(), 10);
        assertEq(fixture.getPoolFee(), 3000);
        assertEq(fixture.getMaxDividendDenominations(), 1);
    }
}
