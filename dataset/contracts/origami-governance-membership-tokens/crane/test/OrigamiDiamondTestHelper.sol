// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import {OrigamiGovernanceToken} from "src/OrigamiGovernanceToken.sol";
import {OrigamiMembershipToken} from "src/OrigamiMembershipToken.sol";
import {OrigamiTimelockController} from "src/OrigamiTimelockController.sol";
import {SimpleCounting} from "src/governor/lib/SimpleCounting.sol";
import {TokenWeightStrategy} from "src/governor/lib/TokenWeightStrategy.sol";

import {GovernorCoreFacet} from "src/governor/GovernorCoreFacet.sol";
import {GovernorSettingsFacet} from "src/governor/GovernorSettingsFacet.sol";
import {GovernorTimelockControlFacet} from "src/governor/GovernorTimelockControlFacet.sol";
import {GovernorDiamondInit, GovernorSettings} from "src/utils/GovernorDiamondInit.sol";
import {DiamondDeployHelper} from "src/utils/DiamondDeployHelper.sol";

import {Test} from "@std/Test.sol";
import {Diamond} from "@diamond/Diamond.sol";
import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";
import {DiamondCutFacet} from "@diamond/facets/DiamondCutFacet.sol";
import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";
import {OwnershipFacet} from "@diamond/facets/OwnershipFacet.sol";

import {ProxyAdmin} from "@oz/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";

abstract contract GovDiamondAddressHelper {
    address public deployer = address(0x1);
    address public owner = address(0x2);
    address public admin = address(0x3);
    address public voter = address(0x4);
    address public voter2 = address(0x5);
    address public voter3 = address(0x6);
    address public voter4 = address(0x7);
    address public newVoter = address(0x8);
    address public nonMember = address(0x9);
    address public signingVoter = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    uint8 public constant FOR = uint8(SimpleCounting.VoteType.For);
    uint8 public constant AGAINST = uint8(SimpleCounting.VoteType.Against);
    uint8 public constant ABSTAIN = uint8(SimpleCounting.VoteType.Abstain);
}

contract GovernorDiamondHelper is GovDiamondAddressHelper, Test {
    OrigamiMembershipToken public memTokenImpl;
    TransparentUpgradeableProxy public memTokenProxy;
    OrigamiMembershipToken public memToken;
    ProxyAdmin public memTokenAdmin;

    OrigamiGovernanceToken public govTokenImpl;
    TransparentUpgradeableProxy public govTokenProxy;
    OrigamiGovernanceToken public govToken;
    ProxyAdmin public govTokenAdmin;

    OrigamiTimelockController public timelock;

    Diamond public origamiGovernorDiamond;

    DiamondLoupeFacet public loupeFacet;
    GovernorCoreFacet public coreFacet;
    GovernorSettingsFacet public settingsFacet;
    GovernorTimelockControlFacet public timelockControlFacet;

    constructor() {
        vm.startPrank(deployer);

        // deploy membership token via proxy
        memTokenAdmin = new ProxyAdmin();
        memTokenImpl = new OrigamiMembershipToken();
        memTokenProxy = new TransparentUpgradeableProxy(
            address(memTokenImpl),
            address(memTokenAdmin),
            ""
        );
        memToken = OrigamiMembershipToken(address(memTokenProxy));
        memToken.initialize(owner, "Deciduous Tree DAO Membership", "DTDM", "https://example.com/metadata/");

        // deploy gov token via proxy
        govTokenAdmin = new ProxyAdmin();
        govTokenImpl = new OrigamiGovernanceToken();
        govTokenProxy = new TransparentUpgradeableProxy(
            address(govTokenImpl),
            address(govTokenAdmin),
            ""
        );
        govToken = OrigamiGovernanceToken(address(govTokenProxy));
        govToken.initialize(owner, "Deciduous Tree DAO Membership", "DTDM", 10000000000000000000000000000);

        GovernorDiamondInit diamondInit = new GovernorDiamondInit();

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](5);

        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();

        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        cuts[0] = DiamondDeployHelper.diamondLoupeFacetCut(address(diamondLoupeFacet));

        OwnershipFacet ownershipFacet = new OwnershipFacet();
        cuts[1] = DiamondDeployHelper.ownershipFacetCut(address(ownershipFacet));

        GovernorCoreFacet governorCoreFacet = new GovernorCoreFacet();

        cuts[2] = DiamondDeployHelper.governorCoreFacetCut(governorCoreFacet);

        GovernorSettingsFacet governorSettingsFacet = new GovernorSettingsFacet();
        cuts[3] = DiamondDeployHelper.governorSettingsFacetCut(governorSettingsFacet);

        GovernorTimelockControlFacet governorTimelockControlFacet = new GovernorTimelockControlFacet();
        cuts[4] = DiamondDeployHelper.governorTimelockControlFacetCut(governorTimelockControlFacet);

        origamiGovernorDiamond = new Diamond(owner, address(diamondCutFacet));

        // initialize the timelock after we have an address for the diamond
        address[] memory proposers = new address[](1);
        proposers[0] = address(origamiGovernorDiamond);
        address[] memory executors = new address[](1);
        executors[0] = address(origamiGovernorDiamond);

        // deploy the timelock
        timelock = new OrigamiTimelockController(1 days, proposers, executors);

        vm.stopPrank();

        GovernorSettings memory settings;
        settings.name = "TestGovernor";
        settings.diamondLoupeFacet = address(diamondLoupeFacet);
        settings.ownershipFacet = address(ownershipFacet);
        settings.governorCoreFacet = address(governorCoreFacet);
        settings.governorSettingsFacet = address(governorSettingsFacet);
        settings.governorTimelockControlFacet = address(governorTimelockControlFacet);
        settings.membershipToken = address(memToken);
        settings.governanceToken = address(govToken);
        settings.defaultProposalToken = address(memToken);
        settings.proposalThresholdToken = address(memToken);
        settings.proposalThreshold = 1;
        settings.votingPeriod = 7 days;
        settings.votingDelay = 7 days;
        settings.quorumNumerator = 10;
        settings.quorumDenominator = 100;
        settings.enableGovernanceToken = true;
        settings.enableMembershipToken = true;

        vm.startPrank(owner);
        DiamondCutFacet(address(origamiGovernorDiamond)).diamondCut(
            cuts,
            address(diamondInit),
            abi.encodeWithSignature("init(address,address,bytes)", admin, timelock, abi.encode(settings))
        );

        // issue the voters membership tokens
        memToken.safeMint(voter);
        memToken.safeMint(voter2);
        memToken.safeMint(voter3);
        memToken.safeMint(voter4);
        memToken.safeMint(newVoter);
        memToken.safeMint(signingVoter);

        // issue the voters gov tokens
        govToken.mint(voter, 100000000); // 10000^2
        govToken.mint(voter2, 225000000); // 15000^2
        govToken.mint(voter3, 56250000); // 7500^2
        govToken.mint(voter4, 306250000); // 17500^2
        govToken.mint(nonMember, 56250000);
        govToken.mint(signingVoter, 100000000);

        // mine, so that proposals snapshot after these mints.
        vm.roll(2);
        vm.stopPrank();

        // self-delegate the NFT
        vm.prank(voter);
        memToken.delegate(voter);
        vm.prank(newVoter);
        memToken.delegate(newVoter);
        vm.prank(voter2);
        memToken.delegate(voter2);
        vm.prank(voter3);
        memToken.delegate(voter3);
        vm.prank(voter4);
        memToken.delegate(voter4);
        vm.prank(signingVoter);
        memToken.delegate(signingVoter);

        // selectively self-delegate the gov token for voters past the first one
        vm.prank(voter2);
        govToken.delegate(voter2);
        vm.prank(voter3);
        govToken.delegate(voter3);
        vm.prank(voter4);
        govToken.delegate(voter4);
        vm.prank(signingVoter);
        govToken.delegate(signingVoter);

        coreFacet = GovernorCoreFacet(address(origamiGovernorDiamond));
        settingsFacet = GovernorSettingsFacet(address(origamiGovernorDiamond));
        timelockControlFacet = GovernorTimelockControlFacet(address(origamiGovernorDiamond));
        loupeFacet = DiamondLoupeFacet(address(origamiGovernorDiamond));

        vm.startPrank(address(timelock));
        settingsFacet.setGovernanceToken(address(govToken));
        settingsFacet.enableProposalToken(address(govToken), true);
        settingsFacet.enableProposalToken(address(memToken), true);
        settingsFacet.enableCountingStrategy(TokenWeightStrategy.simpleWeightSelector, true);
        settingsFacet.enableCountingStrategy(TokenWeightStrategy.quadraticWeightSelector, true);
        vm.stopPrank();

        vm.roll(42);
    }
}
