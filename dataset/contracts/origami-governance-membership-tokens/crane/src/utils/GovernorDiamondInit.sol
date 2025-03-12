// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IAccessControl} from "src/interfaces/IAccessControl.sol";
import {IGovernor} from "src/interfaces/IGovernor.sol";
import {IGovernorProposalQuorum} from "src/interfaces/IGovernorProposalQuorum.sol";
import {IGovernorSettings} from "src/interfaces/IGovernorSettings.sol";
import {IGovernorTimelockControl} from "src/interfaces/IGovernorTimelockControl.sol";
import {AccessControlStorage} from "src/utils/AccessControlStorage.sol";
import {GovernorStorage} from "src/utils/GovernorStorage.sol";

import {LibDiamond} from "@diamond/libraries/LibDiamond.sol";
import {IDiamondLoupe} from "@diamond/interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";
import {IERC173} from "@diamond/interfaces/IERC173.sol";
import {IERC165} from "@diamond/interfaces/IERC165.sol";

// EIP-2535 specifies that the `diamondCut` function takes two optional
// arguments: address _init and bytes calldata _calldata
// These arguments are used to execute an arbitrary function using delegatecall
// in order to set state variables in the diamond during deployment or an upgrade
// More info here: https://eips.ethereum.org/EIPS/eip-2535#diamond-interface

struct GovernorSettings {
    string name;
    address diamondLoupeFacet;
    address ownershipFacet;
    address governorCoreFacet;
    address governorSettingsFacet;
    address governorTimelockControlFacet;
    address membershipToken;
    address governanceToken;
    address defaultProposalToken;
    address proposalThresholdToken;
    uint256 proposalThreshold;
    uint64 votingPeriod;
    uint64 votingDelay;
    uint128 quorumNumerator;
    uint128 quorumDenominator;
    bool enableGovernanceToken;
    bool enableMembershipToken;
}

/**
 * @title Governor Diamond Initializer
 * @author Origami
 * @notice this contract is used to initialize the Governor Diamond.
 * @dev all state that's required at initialization must be set here.
 * @custom:security-contact contract-security@joinorigami.com
 */
contract GovernorDiamondInit {
    function specifySupportedInterfaces() internal {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        // adding ERC165 data
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        // governor diamond specific
        ds.supportedInterfaces[type(IAccessControl).interfaceId] = true;
        ds.supportedInterfaces[type(IGovernor).interfaceId] = true;
        ds.supportedInterfaces[type(IGovernorProposalQuorum).interfaceId] = true;
        ds.supportedInterfaces[type(IGovernorSettings).interfaceId] = true;
        ds.supportedInterfaces[type(IGovernorTimelockControl).interfaceId] = true;
    }

    function initializeRoles(address admin) internal {
        AccessControlStorage.RoleStorage storage rs = AccessControlStorage.roleStorage();
        // 0x0 is the DEFAULT_ADMIN_ROLE
        rs.roles[0x0].members[admin] = true;
    }

    function setProposalTokens(GovernorSettings memory settings) internal {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        config.membershipToken = settings.membershipToken;
        config.governanceToken = settings.governanceToken;
        config.defaultProposalToken = settings.defaultProposalToken;
        config.proposalTokens[settings.membershipToken] = settings.enableMembershipToken;
        config.proposalTokens[settings.governanceToken] = settings.enableGovernanceToken;
    }

    function setDefaultCountingStrategy() internal {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        // // by default, we only configure and enable the simple counting strategy
        config.defaultCountingStrategy = 0x6c4b0e9f;
        config.countingStrategies[0x6c4b0e9f] = true;
    }

    function setConfigurationValues(address admin, address payable timelock, GovernorSettings memory settings)
        internal
    {
        GovernorStorage.GovernorConfig storage config = GovernorStorage.configStorage();
        config.name = settings.name;
        config.admin = admin;
        config.timelock = timelock;
        config.votingDelay = settings.votingDelay;
        config.votingPeriod = settings.votingPeriod;
        config.proposalThreshold = settings.proposalThreshold;
        config.proposalThresholdToken = settings.proposalThresholdToken;
        config.quorumNumerator = settings.quorumNumerator;
        config.quorumDenominator = settings.quorumDenominator;
    }

    function init(address admin, address payable timelock, bytes memory configuration) external {
        GovernorSettings memory settings = abi.decode(configuration, (GovernorSettings));
        specifySupportedInterfaces();
        initializeRoles(admin);
        setDefaultCountingStrategy();
        setProposalTokens(settings);
        setConfigurationValues(admin, timelock, settings);
    }
}
