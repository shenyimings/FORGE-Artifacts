// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import {
    GovernorCompatibilityBravo
} from "@openzeppelin/contracts/governance/compatibility/GovernorCompatibilityBravo.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";
import { IGovernorTimelock } from "@openzeppelin/contracts/governance/extensions/IGovernorTimelock.sol";
import "frax-std/FraxTest.sol";
import { SafeTestTools, SafeTestLib, SafeInstance, DeployedSafe, ModuleManager } from "safe-tools/SafeTestTools.sol";
import { FraxGovernorAlpha, ConstructorParams } from "../src/FraxGovernorAlpha.sol";
import { FraxGovernorOmega, SafeConfig } from "../src/FraxGovernorOmega.sol";
import "../src/VeFxsVotingDelegation.sol";
import "../src/FraxGuard.sol";
import "./mock/FxsMock.sol";
import "./utils/VyperDeployer.sol";
import "../src/interfaces/IFraxGovernorAlpha.sol";
import "../src/interfaces/IFraxGovernorOmega.sol";
import { FraxGovernorBase } from "../src/FraxGovernorBase.sol";
import {
    deployFraxGovernorAlpha,
    deployFraxGovernorOmega,
    deployFraxGuard,
    deployTimelockController,
    deployVeFxsVotingDelegation,
    SafeConfig
} from "script/DeployFraxGovernance.s.sol";
import { deployMockFxs, deployVeFxs } from "../script/test/DeployTestFxs.s.sol";
import { Constants } from "../script/Constants.sol";

contract FraxGovernorTestBase is FraxTest, SafeTestTools {
    using SafeTestLib for SafeInstance;

    TestAccount[] accounts;
    TestAccount[] eoaOwners;

    SafeInstance safe;
    SafeInstance safe2;
    ISafe multisig;
    ISafe multisig2;
    IVeFxsVotingDelegation veFxsVotingDelegation;
    IFraxGovernorAlpha fraxGovernorAlpha;
    TimelockController timelockController;
    IFraxGovernorOmega fraxGovernorOmega;
    FraxGuard fraxGuard;

    FxsMock fxs;
    IVeFxs veFxs;

    address constant bob = address(0xb0b);

    uint256 constant numAccounts = 10;
    uint256 internal constant GUARD_STORAGE_OFFSET =
        33_528_237_782_592_280_163_068_556_224_972_516_439_282_563_014_722_366_175_641_814_928_123_294_921_928;
    uint256 public constant BLOCK_TIME = 12;

    VyperDeployer immutable vyperDeployer = new VyperDeployer();

    struct TestAccount {
        address account;
        uint256 pk;
    }

    function _bytesToAddress(bytes memory b) internal pure returns (address addr) {
        assembly {
            addr := mload(add(b, 32))
        }
    }

    function setUp() public virtual {
        // Set more realistic timestamps and block numbers
        vm.warp(1_680_000_000);
        vm.roll(17_100_000);

        TestAccount[] memory _accounts = generateAddresses(numAccounts);
        for (uint256 i = 0; i < numAccounts; ++i) {
            accounts.push(_accounts[i]);
            if (i < 5) {
                eoaOwners.push(_accounts[i]);
            }
        }

        //setup Gnosis safe
        uint256[] memory _owners = new uint256[](5);
        for (uint256 i = 0; i < eoaOwners.length; ++i) {
            _owners[i] = eoaOwners[i].pk;
        }
        safe = _setupSafe({ ownerPKs: _owners, threshold: 1, initialBalance: 0 });
        safe2 = _setupSafe({ ownerPKs: _owners, threshold: 1, initialBalance: 0 });
        multisig = ISafe(address(getSafe().safe));
        multisig2 = ISafe(address(getSafe(address(safe2.safe)).safe));

        (address _mockFxs, , ) = deployMockFxs();
        fxs = FxsMock(_mockFxs);

        (address _mockVeFxs, , ) = deployVeFxs(vyperDeployer, _mockFxs);
        veFxs = IVeFxs(_mockVeFxs);

        (address _veFxsVotingDelegation, , ) = deployVeFxsVotingDelegation(_mockVeFxs);
        veFxsVotingDelegation = IVeFxsVotingDelegation(_veFxsVotingDelegation);

        (address payable _timelockController, , ) = deployTimelockController(address(this));
        timelockController = TimelockController(_timelockController);

        (address payable _fraxGovernorAlpha, , ) = deployFraxGovernorAlpha(
            _mockVeFxs,
            _veFxsVotingDelegation,
            _timelockController
        );
        fraxGovernorAlpha = IFraxGovernorAlpha(_fraxGovernorAlpha);

        timelockController.grantRole(timelockController.PROPOSER_ROLE(), _fraxGovernorAlpha);
        timelockController.grantRole(timelockController.EXECUTOR_ROLE(), _fraxGovernorAlpha);
        timelockController.grantRole(timelockController.CANCELLER_ROLE(), _fraxGovernorAlpha);
        timelockController.renounceRole(timelockController.TIMELOCK_ADMIN_ROLE(), address(this));

        SafeConfig[] memory _safeConfigs = new SafeConfig[](2);
        _safeConfigs[0] = SafeConfig({ safe: address(multisig), requiredSignatures: 3 });
        _safeConfigs[1] = SafeConfig({ safe: address(multisig2), requiredSignatures: 3 });

        (address payable _fraxGovernorOmega, , ) = deployFraxGovernorOmega(
            _mockVeFxs,
            _veFxsVotingDelegation,
            _safeConfigs,
            _timelockController
        );
        fraxGovernorOmega = IFraxGovernorOmega(_fraxGovernorOmega);

        (address _fraxGuard, , ) = deployFraxGuard(_fraxGovernorOmega);
        fraxGuard = FraxGuard(_fraxGuard);

        SafeTestLib.enableModule({ instance: getSafe(address(multisig)), module: address(timelockController) });
        SafeTestLib.enableModule({ instance: getSafe(address(multisig2)), module: address(timelockController) });

        // add frxGovOmega signer
        addSignerToSafe({
            _safe: address(multisig),
            signer: eoaOwners[0].account,
            newOwner: address(fraxGovernorOmega),
            threshold: 4
        });
        addSignerToSafe({
            _safe: address(multisig2),
            signer: eoaOwners[0].account,
            newOwner: address(fraxGovernorOmega),
            threshold: 4
        });

        // call setGuard on Safe
        setupFraxGuard({ _safe: address(multisig), signer: eoaOwners[0].account, _fraxGuard: address(fraxGuard) });
        setupFraxGuard({ _safe: address(multisig2), signer: eoaOwners[0].account, _fraxGuard: address(fraxGuard) });

        assertEq(getSafe(address(multisig)).safe.getOwners().length, 6, "6 total safe owners");
        assertEq(getSafe(address(multisig)).safe.getThreshold(), 4, "4 signatures required");
        assert(getSafe(address(multisig)).safe.isModuleEnabled(address(timelockController)));
        assertEq(
            address(fraxGuard),
            _bytesToAddress(getSafe(address(multisig)).safe.getStorageAt({ offset: GUARD_STORAGE_OFFSET, length: 1 })),
            "Guard is set"
        );

        assertEq(getSafe(address(multisig2)).safe.getOwners().length, 6, "6 total safe owners");
        assertEq(getSafe(address(multisig2)).safe.getThreshold(), 4, "4 signatures required");
        assert(getSafe(address(multisig2)).safe.isModuleEnabled(address(timelockController)));
        assertEq(
            address(fraxGuard),
            _bytesToAddress(getSafe(address(multisig2)).safe.getStorageAt({ offset: GUARD_STORAGE_OFFSET, length: 1 })),
            "Guard is set"
        );

        uint256 amount = 100_000e18;

        // Give FXS balances to every account
        for (uint256 i = 0; i < accounts.length; ++i) {
            deal(address(fxs), accounts[i].account, amount);
            assertEq(fxs.balanceOf(accounts[i].account), amount, "account gets FXS");
        }

        // even distribution of lock time / veFXS balance
        for (uint256 i = 0; i < accounts.length; ++i) {
            address account = accounts[i].account;
            vm.startPrank(account, account);
            fxs.increaseAllowance(address(veFxs), amount);
            veFxs.create_lock(amount, block.timestamp + (365 days * 4) / (i + 1));
            vm.stopPrank();
            assertGt(veFxs.balanceOf(account), amount, "veFXS for an account is always equal to or greater than FXS");
        }

        assertGt(
            veFxs.balanceOf(accounts[0].account),
            veFxs.balanceOf(accounts[accounts.length - 1].account),
            "Descending veFXS balances"
        );

        vm.warp(block.timestamp + BLOCK_TIME);
        vm.roll(block.number + 1);
    }

    // Generic Helpers

    function buildContractPreapprovalSignature(address contractOwner) public pure returns (bytes memory) {
        // GnosisSafe Pre-Validated signature format:
        // {32-bytes hash validator}{32-bytes ignored}{1-byte signature type}
        return abi.encodePacked(uint96(0), uint160(contractOwner), uint256(0), uint8(1));
    }

    function twoEoaSigs(bytes32 txHash) public view returns (bytes memory) {
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(eoaOwners[2].pk, txHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(eoaOwners[0].pk, txHash);
        return abi.encodePacked(r2, s2, v2, r, s, v);
    }

    function generateThreeEOASigs(bytes32 txHash) public view returns (bytes memory) {
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(eoaOwners[1].pk, txHash);
        return abi.encodePacked(twoEoaSigs(txHash), r1, s1, v1); // sorted as needed for Gnosis Safe
    }

    function generateFourEoaSigs(bytes32 txHash) public view returns (bytes memory) {
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(eoaOwners[1].pk, txHash);
        (uint8 v3, bytes32 r3, bytes32 s3) = vm.sign(eoaOwners[3].pk, txHash);
        return abi.encodePacked(twoEoaSigs(txHash), r3, s3, v3, r1, s1, v1); // sorted as needed for Gnosis Safe
    }

    function twoOtherEoaSigs(bytes32 txHash) public view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(eoaOwners[0].pk, txHash);
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(eoaOwners[1].pk, txHash);
        return abi.encodePacked(r, s, v, r1, s1, v1); // sorted as needed for Gnosis Safe
    }

    function generateThreeEoaSigsAndOmega(bytes32 txHash) public view returns (bytes memory) {
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(eoaOwners[2].pk, txHash);
        return
            abi.encodePacked(
                r2,
                s2,
                v2,
                buildContractPreapprovalSignature(address(fraxGovernorOmega)),
                twoOtherEoaSigs(txHash)
            ); // sorted as needed for Gnosis Safe
    }

    function generateThreeEoaSigsWrongOrder(bytes32 txHash) public view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(eoaOwners[0].pk, txHash);
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(eoaOwners[1].pk, txHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(eoaOwners[2].pk, txHash);
        return abi.encodePacked(r, s, v, r2, s2, v2, r1, s1, v1); // wrong order
    }

    function generateAddresses(uint256 num) public returns (TestAccount[] memory) {
        TestAccount[] memory _accounts = new TestAccount[](num);
        for (uint256 i = 0; i < num; ++i) {
            (address account, uint256 pk) = makeAddrAndKey(string(abi.encodePacked(i)));
            TestAccount memory a = TestAccount(account, pk);
            _accounts[i] = a;
        }
        return _accounts;
    }

    function dealLockMoreFxs(address account, uint256 amount) public {
        deal(address(fxs), account, amount);
        vm.startPrank(account, account);
        fxs.increaseAllowance(address(veFxs), amount);
        veFxs.increase_amount(amount);
        vm.stopPrank();
        vm.warp(block.timestamp + BLOCK_TIME);
        vm.roll(block.number + 1);
    }

    function setupFraxGuard(address _safe, address signer, address _fraxGuard) public {
        bytes memory data = abi.encodeWithSignature("setGuard(address)", address(_fraxGuard));
        DeployedSafe _dsafe = getSafe(_safe).safe;
        bytes32 txHash = _dsafe.getTransactionHash(
            address(_dsafe),
            0,
            data,
            Enum.Operation.Call,
            0,
            0,
            0,
            payable(address(0)),
            payable(address(0)),
            _dsafe.nonce()
        );

        hoax(signer);
        _dsafe.execTransaction(
            address(_dsafe),
            0,
            data,
            Enum.Operation.Call,
            0,
            0,
            0,
            payable(address(0)),
            payable(address(0)),
            generateFourEoaSigs(txHash)
        );
    }

    function addSignerToSafe(address _safe, address signer, address newOwner, uint256 threshold) internal {
        bytes memory data = abi.encodeWithSignature("addOwnerWithThreshold(address,uint256)", newOwner, threshold);
        bytes memory sig = buildContractPreapprovalSignature(signer);

        hoax(signer);
        getSafe(_safe).safe.execTransaction(
            address(getSafe(_safe).safe),
            0,
            data,
            Enum.Operation.Call,
            0,
            0,
            0,
            payable(address(0)),
            payable(address(0)),
            sig
        );
    }

    // Creating proposals
    function optimisticTxProposalHash(
        address _safe,
        IFraxGovernorOmega _fraxGovernorOmega,
        bytes32 txHash
    ) public pure returns (uint256, address[] memory, uint256[] memory, bytes[] memory) {
        bytes memory data = abi.encodeWithSelector(ISafe.approveHash.selector, txHash);

        address[] memory targets = new address[](1);
        targets[0] = _safe;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = data;
        return (
            _fraxGovernorOmega.hashProposal(targets, values, calldatas, keccak256(bytes(""))),
            targets,
            values,
            calldatas
        );
    }

    function createNoOpProposal(
        address _safe,
        address to,
        uint256 nonce
    ) public view returns (bytes32, IFraxGovernorOmega.TxHashArgs memory) {
        return (
            getSafe(_safe).safe.getTransactionHash(
                to,
                0,
                "",
                Enum.Operation.Call,
                0,
                0,
                0,
                address(0),
                address(0),
                nonce
            ),
            IFraxGovernorOmega.TxHashArgs(to, 0, "", Enum.Operation.Call, 0, 0, 0, address(0), address(0), nonce)
        );
    }

    function createTransferFxsProposal(
        address _safe,
        uint256 nonce
    ) public view returns (bytes32, IFraxGovernorOmega.TxHashArgs memory) {
        return (
            getSafe(_safe).safe.getTransactionHash(
                address(fxs),
                0,
                abi.encodeWithSignature("transfer(address,uint256)", address(this), 100e18),
                Enum.Operation.Call,
                0,
                0,
                0,
                address(0),
                address(0),
                nonce
            ),
            IFraxGovernorOmega.TxHashArgs(
                address(fxs),
                0,
                abi.encodeWithSignature("transfer(address,uint256)", address(this), 100e18),
                Enum.Operation.Call,
                0,
                0,
                0,
                address(0),
                address(0),
                nonce
            )
        );
    }

    function createOptimisticTxProposal(
        address _safe,
        IFraxGovernorOmega _fraxGovernorOmega,
        address caller,
        uint256 nonce
    ) public returns (uint256 pid, address[] memory targets, uint256[] memory values, bytes[] memory calldatas) {
        (bytes32 txHash, IFraxGovernorOmega.TxHashArgs memory args) = createNoOpProposal(_safe, address(0), nonce);

        (pid, targets, values, calldatas) = optimisticTxProposalHash(_safe, _fraxGovernorOmega, txHash);
        hoax(caller);
        vm.expectEmit(true, true, true, true);
        emit TransactionProposed(_safe, nonce, txHash, pid, caller);
        _fraxGovernorOmega.addTransaction(address(_safe), args, generateThreeEOASigs(txHash));
    }

    function createOptimisticProposal(
        address _safe,
        IFraxGovernorOmega _fraxGovernorOmega,
        address caller,
        uint256 nonce
    ) public returns (uint256 pid, address[] memory targets, uint256[] memory values, bytes[] memory calldatas) {
        (bytes32 txHash, IFraxGovernorOmega.TxHashArgs memory args) = createTransferFxsProposal(_safe, nonce);

        (pid, targets, values, calldatas) = optimisticTxProposalHash(_safe, _fraxGovernorOmega, txHash);
        hoax(caller);
        vm.expectEmit(true, true, true, true);
        emit TransactionProposed(_safe, nonce, txHash, pid, caller);
        _fraxGovernorOmega.addTransaction(address(_safe), args, generateThreeEOASigs(txHash));
    }

    function genericAlphaSafeProposalData(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) public pure returns (bytes memory) {
        return abi.encodeWithSelector(ModuleManager.execTransactionFromModule.selector, to, value, data, operation);
    }

    function swapOwnerProposalHash(
        IFraxGovernorAlpha _fraxGovernorAlpha,
        ISafe _safe,
        address prevOwner,
        address oldOwner,
        address newOwner
    ) public pure returns (uint256, address[] memory, uint256[] memory, bytes[] memory) {
        bytes memory data = genericAlphaSafeProposalData(
            address(_safe),
            0,
            abi.encodeWithSignature("swapOwner(address,address,address)", prevOwner, oldOwner, newOwner),
            Enum.Operation.Call
        );

        address[] memory targets = new address[](1);
        targets[0] = address(_safe);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = data;

        return (
            _fraxGovernorAlpha.hashProposal(targets, values, calldatas, keccak256(bytes(""))),
            targets,
            values,
            calldatas
        );
    }

    struct CreateSwapOwnerProposalParams {
        IFraxGovernorAlpha _fraxGovernorAlpha;
        ISafe _safe;
        address proposer;
        address prevOwner;
        address oldOwner;
    }

    function createSwapOwnerProposal(
        CreateSwapOwnerProposalParams memory params
    ) public returns (uint256 pid, address[] memory targets, uint256[] memory values, bytes[] memory calldatas) {
        (pid, targets, values, calldatas) = swapOwnerProposalHash(
            params._fraxGovernorAlpha,
            params._safe,
            params.prevOwner,
            params.oldOwner,
            params.proposer
        );
        vm.startPrank(params.proposer);
        vm.expectEmit(true, true, true, true);
        emit ProposalCreated({
            proposalId: pid,
            proposer: params.proposer,
            targets: targets,
            values: values,
            signatures: new string[](targets.length),
            calldatas: calldatas,
            voteStart: block.timestamp + params._fraxGovernorAlpha.votingDelay(),
            voteEnd: block.timestamp +
                params._fraxGovernorAlpha.votingDelay() +
                params._fraxGovernorAlpha.votingPeriod(),
            description: ""
        });
        params._fraxGovernorAlpha.propose(targets, values, calldatas, "");
        vm.stopPrank();
    }

    // Events

    event TransactionProposed(
        address indexed safe,
        uint256 nonce,
        bytes32 txHash,
        uint256 proposalId,
        address indexed proposer
    );

    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);
    event VotingDelayBlocksSet(uint256 oldVotingDelayBlocks, uint256 newVotingDelayBlocks);
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);
    event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);
    event VeFxsVotingDelegationSet(address oldVotingDelegation, address newVotingDelegation);
    event QuorumNumeratorUpdated(uint256 oldQuorumNumerator, uint256 newQuorumNumerator);
    event ShortCircuitNumeratorUpdated(uint256 oldShortCircuitThreshold, uint256 newShortCircuitThreshold);
    event TimelockChange(address oldTimelock, address newTimelock);

    event SafeConfigUpdate(address indexed safe, uint256 oldRequiredSignatures, uint256 newRequiredSignatures);

    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 voteStart,
        uint256 voteEnd,
        string description
    );
    event ProposalCanceled(uint256 proposalId);

    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);
}
