// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { BaseScript } from "frax-std/BaseScript.sol";
import { console } from "frax-std/FraxTest.sol";
import { Constants } from "../script/Constants.sol";
import { FraxGovernorAlpha, ConstructorParams as FraxAlphaGovernorParams } from "../src/FraxGovernorAlpha.sol";
import {
    FraxGovernorOmega,
    ConstructorParams as FraxGovernorOmegaParams,
    SafeConfig
} from "../src/FraxGovernorOmega.sol";
import { FraxGuard } from "../src/FraxGuard.sol";
import { VeFxsVotingDelegation } from "../src/VeFxsVotingDelegation.sol";

function deployVeFxsVotingDelegation(
    address _veFxs
) returns (address payable _address, bytes memory _constructorParams, string memory _contractName) {
    _constructorParams = abi.encode(_veFxs);
    _contractName = "VeFxsVotingDelegation";
    _address = payable(address(new VeFxsVotingDelegation(_veFxs)));
}

function deployTimelockController(
    address admin
) returns (address payable _address, bytes memory _constructorParams, string memory _contractName) {
    uint256 minDelay = 1 days;
    address[] memory proposers = new address[](0);
    address[] memory executors = new address[](0);
    _constructorParams = abi.encode(minDelay, proposers, executors, admin);
    _contractName = "TimelockController";
    _address = payable(address(new TimelockController(minDelay, proposers, executors, admin)));
}

function deployFraxGovernorAlpha(
    address _veFxs,
    address _veFxsVotingDelegation,
    address payable _timelockController
) returns (address payable _address, bytes memory _constructorParams, string memory _contractName) {
    FraxAlphaGovernorParams memory _params = FraxAlphaGovernorParams({
        veFxs: _veFxs,
        veFxsVotingDelegation: _veFxsVotingDelegation,
        timelockController: _timelockController,
        initialVotingDelay: 1 days,
        initialVotingPeriod: 5 days,
        initialProposalThreshold: Constants.INITIAL_PROPOSAL_THRESHOLD,
        quorumNumeratorValue: 40,
        initialVotingDelayBlocks: 1 days / 12,
        initialShortCircuitNumerator: Constants.INITIAL_SHORT_CIRCUIT_THRESHOLD
    });

    _constructorParams = abi.encode(_params);
    _contractName = "FraxGovernorAlpha";
    _address = payable(address(new FraxGovernorAlpha(_params)));
}

function deployFraxGovernorOmega(
    address _veFxs,
    address _veFxsVotingDelegation,
    SafeConfig[] memory _safeConfigs,
    address payable _timelockController
) returns (address payable _address, bytes memory _constructorParams, string memory _contractName) {
    FraxGovernorOmegaParams memory _params = FraxGovernorOmegaParams({
        veFxs: _veFxs,
        veFxsVotingDelegation: _veFxsVotingDelegation,
        safeConfigs: _safeConfigs,
        timelockController: _timelockController,
        initialVotingDelay: 1 minutes,
        initialVotingPeriod: 2 days,
        initialProposalThreshold: Constants.INITIAL_PROPOSAL_THRESHOLD,
        quorumNumeratorValue: 4,
        initialVotingDelayBlocks: 1 minutes / 12,
        initialShortCircuitNumerator: Constants.INITIAL_SHORT_CIRCUIT_THRESHOLD
    });

    _constructorParams = abi.encode(_params);
    _contractName = "FraxGovernorOmega";
    _address = payable(address(new FraxGovernorOmega(_params)));
}

function deployFraxGuard(
    address _fraxGovernorOmega
) returns (address _address, bytes memory _constructorParams, string memory _contractName) {
    _constructorParams = abi.encode(_fraxGovernorOmega);
    _contractName = "FraxGuard";
    _address = address(new FraxGuard(_fraxGovernorOmega));
}

contract DeployFraxGovernance is BaseScript {
    function run()
        external
        broadcaster
        returns (address payable _address, bytes memory _constructorParams, string memory _contractName)
    {
        (address _addressVoting, bytes memory _constructorParamsVoting, ) = deployVeFxsVotingDelegation(
            Constants.VE_FXS
        );
        console.log("_constructorParamsVoting:", string(abi.encode(_constructorParamsVoting)));
        console.logBytes(_constructorParamsVoting);
        console.log("_addressVoting:", _addressVoting);

        (address payable _addressTimelock, bytes memory _constructorParamsTimelock, ) = deployTimelockController(
            deployer
        );
        console.log("_constructorParamsTimelock:", string(abi.encode(_constructorParamsTimelock)));
        console.logBytes(_constructorParamsTimelock);
        console.log("_addressTimelock:", _addressTimelock);

        (_address, _constructorParams, _contractName) = deployFraxGovernorAlpha(
            Constants.VE_FXS,
            _addressVoting,
            _addressTimelock
        );
        console.log("_constructorParamsAlpha:", string(abi.encode(_constructorParams)));
        console.logBytes(_constructorParams);
        console.log("_addressAlpha:", _address);

        TimelockController tc = TimelockController(_addressTimelock);

        tc.grantRole(tc.PROPOSER_ROLE(), _address);
        tc.grantRole(tc.EXECUTOR_ROLE(), _address);
        tc.grantRole(tc.CANCELLER_ROLE(), _address);
        tc.renounceRole(tc.TIMELOCK_ADMIN_ROLE(), deployer);

        SafeConfig[] memory _safeConfigs = new SafeConfig[](2);
        //        _safeConfigs[0] = SafeConfig({safe: address(0), requiredSignatures: 3}); //TODO: prod values
        (
            address _addressOmega,
            bytes memory _constructorParamsOmega /* string memory _contractNameOmega */,

        ) = deployFraxGovernorOmega(Constants.VE_FXS, _addressVoting, _safeConfigs, _addressTimelock);
        console.log("_constructorParamsOmega:", string(abi.encode(_constructorParamsOmega)));
        console.logBytes(_constructorParamsOmega);
        console.log("_addressOmega:", _addressOmega);

        (
            address _addressGuard,
            bytes memory _constructorParamsGuard /* string memory _contractNameGuard */,

        ) = deployFraxGuard(_addressOmega);
        console.log("_constructorParamsGuard:", string(abi.encode(_constructorParamsGuard)));
        console.logBytes(_constructorParamsGuard);
        console.log("_addressGuard:", _addressGuard);
    }
}
