// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "./FraxGovernorTestBase.t.sol";

contract TestFraxGovernorUpgrade is FraxGovernorTestBase {
    IFraxGovernorAlpha fraxGovernorAlphaUpgrade;
    TimelockController timelockControllerUpgrade;
    IFraxGovernorOmega fraxGovernorOmegaUpgrade;
    FraxGuard fraxGuardUpgrade;

    function setUp() public override {
        super.setUp();

        (address payable _timelockController, , ) = deployTimelockController(address(this));
        timelockControllerUpgrade = TimelockController(_timelockController);

        (address payable _fraxGovernorAlpha, , ) = deployFraxGovernorAlpha(
            address(veFxs),
            address(veFxsVotingDelegation),
            _timelockController
        );
        fraxGovernorAlphaUpgrade = IFraxGovernorAlpha(_fraxGovernorAlpha);

        timelockControllerUpgrade.grantRole(timelockControllerUpgrade.PROPOSER_ROLE(), _fraxGovernorAlpha);
        timelockControllerUpgrade.grantRole(timelockControllerUpgrade.EXECUTOR_ROLE(), _fraxGovernorAlpha);
        timelockControllerUpgrade.grantRole(timelockControllerUpgrade.CANCELLER_ROLE(), _fraxGovernorAlpha);
        timelockControllerUpgrade.renounceRole(timelockControllerUpgrade.TIMELOCK_ADMIN_ROLE(), address(this));

        SafeConfig[] memory _safeConfigs = new SafeConfig[](1);
        _safeConfigs[0] = SafeConfig({ safe: address(multisig), requiredSignatures: 3 });

        (address payable _fraxGovernorOmega, , ) = deployFraxGovernorOmega(
            address(veFxs),
            address(veFxsVotingDelegation),
            _safeConfigs,
            _timelockController
        );
        fraxGovernorOmegaUpgrade = IFraxGovernorOmega(_fraxGovernorOmega);

        (address _fraxGuard, , ) = deployFraxGuard(_fraxGovernorOmega);
        fraxGuardUpgrade = FraxGuard(_fraxGuard);
    }

    // create and execute proposal to remove old frxGov from multisig and set up with new frxGov
    function testUpgradeGovernance() public {
        address[] memory targets = new address[](5);
        uint256[] memory values = new uint256[](5);
        bytes[] memory calldatas = new bytes[](5);
        DeployedSafe _safe = getSafe(address(multisig)).safe;

        // Switch fraxGuard to new one
        targets[0] = address(multisig);
        calldatas[0] = genericAlphaSafeProposalData(
            address(multisig),
            0,
            abi.encodeWithSignature("setGuard(address)", address(fraxGuardUpgrade)),
            Enum.Operation.Call
        );

        // Add new timelock as module
        targets[1] = address(multisig);
        calldatas[1] = genericAlphaSafeProposalData(
            address(multisig),
            0,
            abi.encodeWithSignature("enableModule(address)", address(fraxGovernorAlphaUpgrade)),
            Enum.Operation.Call
        );

        // Swap owner oldOmega to new omega
        targets[2] = address(multisig);
        calldatas[2] = genericAlphaSafeProposalData(
            address(multisig),
            0,
            abi.encodeWithSignature(
                "swapOwner(address,address,address)",
                address(0x1), // prevOwner
                address(fraxGovernorOmega), // oldOwner
                address(fraxGovernorOmegaUpgrade) // newOwner
            ),
            Enum.Operation.Call
        );

        // Remove safe from old omega allowlist
        SafeConfig[] memory _safeConfigs = new SafeConfig[](1);
        _safeConfigs[0] = SafeConfig({ safe: address(multisig), requiredSignatures: 0 });

        targets[3] = address(fraxGovernorOmega);
        calldatas[3] = abi.encodeWithSelector(IFraxGovernorOmega.updateSafes.selector, _safeConfigs);

        // Remove old timelock as module
        targets[4] = address(multisig);
        calldatas[4] = genericAlphaSafeProposalData(
            address(multisig),
            0,
            abi.encodeWithSignature(
                "disableModule(address,address)",
                address(fraxGovernorAlphaUpgrade), // prevModule
                address(fraxGovernorAlpha) // module
            ),
            Enum.Operation.Call
        );

        hoax(accounts[0].account);
        uint256 proposalId = fraxGovernorAlpha.propose(targets, values, calldatas, "");

        vm.warp(block.timestamp + fraxGovernorAlpha.votingPeriod());
        vm.roll(block.number + fraxGovernorAlpha.votingPeriod() / BLOCK_TIME);

        for (uint256 i = 0; i < accounts.length; ++i) {
            if (uint256(fraxGovernorAlpha.state(proposalId)) == uint256(IGovernor.ProposalState.Active)) {
                hoax(accounts[i].account);
                fraxGovernorAlpha.castVote(proposalId, uint8(GovernorCompatibilityBravo.VoteType.For));
            }
        }

        assertEq(
            uint256(IGovernor.ProposalState.Succeeded),
            uint256(fraxGovernorAlpha.state(proposalId)),
            "Proposal state is succeeded"
        );

        fraxGovernorAlpha.queue(targets, values, calldatas, keccak256(bytes("")));

        vm.warp(fraxGovernorAlpha.proposalEta(proposalId));

        fraxGovernorAlpha.execute(targets, values, calldatas, keccak256(bytes("")));

        assertEq(
            uint256(IGovernor.ProposalState.Executed),
            uint256(fraxGovernorAlpha.state(proposalId)),
            "Proposal state is executed"
        );

        assertEq(
            address(fraxGuardUpgrade),
            _bytesToAddress(_safe.getStorageAt({ offset: GUARD_STORAGE_OFFSET, length: 1 })),
            "New Frax Guard is set"
        );

        assertTrue(_safe.isModuleEnabled(address(fraxGovernorAlphaUpgrade)), "New Alpha is a module");

        assertFalse(_safe.isOwner(address(fraxGovernorOmega)), "Old Omega removed as safe owner");

        assertTrue(_safe.isOwner(address(fraxGovernorOmegaUpgrade)), "New Omega is safe owner");

        assertEq(
            fraxGovernorOmega.$safeRequiredSignatures(address(multisig)),
            0,
            "Removed safe from old omega allowlist"
        );

        assertFalse(_safe.isModuleEnabled(address(fraxGovernorAlpha)), "Old Alpha removed as module");

        assertEq(_safe.getOwners().length, 6, "6 total safe owners");
        assertEq(_safe.getThreshold(), 4, "4 signatures required");
    }
}
