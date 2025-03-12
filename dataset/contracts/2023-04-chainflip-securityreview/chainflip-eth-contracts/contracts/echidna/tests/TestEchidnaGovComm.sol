pragma solidity ^0.8.0;

import "../contracts/DeployerEchidna.sol";

contract TestEchidnaGovComm is DeployerEchidna {
    address internal govKey = address(this);
    address internal commKey = address(this);
    uint256 internal minStake = 1000 * E_18;

    // Echidna requires that no parameters are passed to the constructor so we need to set
    // constants for the deployments of the contracts
    constructor()
        DeployerEchidna(
            Key(PUBKEYX, PUBKEYYPARITY),
            govKey,
            commKey,
            minStake,
            INIT_SUPPLY,
            NUM_GENESIS_VALIDATORS,
            GENESIS_STAKE
        )
    {}

    // PROPERTY TESTING - need to run echidna in testMode: "property"

    // No function call that requires signing should pass the signature check - checking that contract state
    // remains the same after the function calls instead of checking function reverts one by one. This is because
    // ´echidna_revert_*` takes no arguments.
    // This contract acts as the governance and community Key.

    /* solhint-disable  func-name-mixedcase*/
    function echidna_flipSupply() external returns (bool) {
        return flip.totalSupply() == INIT_SUPPLY;
    }

    function echidna_kmReference() external returns (bool) {
        return
            flip.getKeyManager() == stakeManager.getKeyManager() &&
            stakeManager.getKeyManager() == vault.getKeyManager() &&
            vault.getKeyManager() == keyManager;
    }

    function echidna_aggKey() external returns (bool) {
        return
            keyManager.getAggregateKey().pubKeyX == PUBKEYX &&
            keyManager.getAggregateKey().pubKeyYParity == PUBKEYYPARITY;
    }

    // Gov key changes
    function setGovKeyWithGovKey(address newGovKey) external override {
        keyManager.setGovKeyWithGovKey(newGovKey);
        govKey = newGovKey;
        assert(
            stakeManager.getGovernor() == vault.getGovernor() &&
                vault.getGovernor() == keyManager.getGovernanceKey() &&
                keyManager.getGovernanceKey() == govKey
        );
    }

    // ASSERTION TESTING - need to run echidna in testMode: "assertion"

    // Comm key changes
    function setCommKeyWithCommKey(address newCommKey) external override {
        keyManager.setCommKeyWithCommKey(newCommKey);
        commKey = newCommKey;
        assert(
            stakeManager.getCommunityKey() == vault.getCommunityKey() &&
                vault.getCommunityKey() == keyManager.getCommunityKey() &&
                keyManager.getCommunityKey() == commKey
        );
    }

    // No signature has been validated
    function echidna_lastValidateTime() external returns (bool) {
        return _lastValidateTime == keyManager.getLastValidateTime();
    }

    function echidna_whitelistSet() external returns (bool) {
        return keyManager.canConsumeKeyNonceSet();
    }

    // Suspend and resume functions
    function suspendVault() external override {
        vault.suspend();
        assert(vault.getSuspendedState() == true);
    }

    function suspendStakeManager() external override {
        stakeManager.suspend();
        assert(stakeManager.getSuspendedState() == true);
    }

    function resumeVault() external override {
        vault.resume();
        assert(vault.getSuspendedState() == false);
    }

    function resumeStakeManager() external override {
        stakeManager.resume();
        assert(stakeManager.getSuspendedState() == false);
    }

    // Community Guard
    function enableCommunityGuardVault() external override {
        vault.enableCommunityGuard();
        assert(vault.getCommunityGuardDisabled() == false);
    }

    function disableCommunityGuardVault() external override {
        vault.disableCommunityGuard();
        assert(vault.getCommunityGuardDisabled() == true);
    }

    function enableCommunityGuardStakeManager() external override {
        vault.enableCommunityGuard();
        assert(vault.getCommunityGuardDisabled() == false);
    }

    function disableCommunityGuardStakeManager() external override {
        stakeManager.disableCommunityGuard();
        assert(stakeManager.getCommunityGuardDisabled() == true);
    }

    function setMinStake(uint256 newMinStake) external override {
        stakeManager.setMinStake(newMinStake);
        minStake = newMinStake;
        assert(stakeManager.getMinimumStake() == minStake);
    }

    function checkwhitelistAddrs() external view {
        assert(keyManager.getNumberWhitelistedAddresses() == 3);
        for (uint256 i = 0; i < whitelist.length; i++) {
            assert(keyManager.canConsumeKeyNonce(whitelist[i]) == true);
        }
    }

    // ´echidna_revert_*´ takes no parameters and expects a revert
    // Different calls expected to revert should be in different echidna_revert_ functions
    // since echidna checks that the call is reverted at any point

    // Proxy for a signed function - Assert if the call is not reverted
    function allBatch_revert(
        SigData calldata sigData,
        DeployFetchParams[] calldata deployFetchParamsArray,
        FetchParams[] calldata fetchParamsArray,
        TransferParams[] calldata transferParamsArray
    ) external {
        try vault.allBatch(sigData, deployFetchParamsArray, fetchParamsArray, transferParamsArray) {
            assert(false);
        } catch {
            assert(true);
        }
    }
    /* solhint-enable  func-name-mixedcase*/
}
