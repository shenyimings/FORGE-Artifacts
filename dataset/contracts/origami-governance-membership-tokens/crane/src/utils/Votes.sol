// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Checkpoints} from "src/utils/Checkpoints.sol";
import {IVotes} from "src/interfaces/IVotes.sol";
import {IVotesToken} from "src/interfaces/IVotesToken.sol";

import {ECDSA} from "@oz/utils/cryptography/ECDSA.sol";

/**
 * @title Votes
 * @notice Implements voting weight calculation for Origami Governance Token
 * @dev This contract is abstract and must be inherited by a contract that implements IVotesToken
 * NB: this is a lightweight integration around Checkpoints.sol that implements IVotes
 * @custom:security-contact contract-security@joinorigami.com
 */
abstract contract Votes is IVotes, IVotesToken {
    /// @notice the typehash for the EIP712 domain separator
    bytes32 public constant EIP712_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    /// @notice the typehash for the delegation struct
    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @inheritdoc IVotes
    function getVotes(address account) public view returns (uint256) {
        return Checkpoints.getVotes(account);
    }

    /// @inheritdoc IVotes
    function getPastVotes(address account, uint256 timestamp) public view returns (uint256) {
        return Checkpoints.getPastVotes(account, timestamp);
    }

    /// @inheritdoc IVotes
    function getPastTotalSupply(uint256 timestamp) external view returns (uint256) {
        return Checkpoints.getPastTotalSupply(timestamp);
    }

    /// @inheritdoc IVotes
    function delegates(address delegator) external view returns (address) {
        return Checkpoints.delegates(delegator);
    }

    /// @inheritdoc IVotes
    function delegate(address delegatee) external {
        handleDelegation(msg.sender, delegatee);
    }

    /// @inheritdoc IVotes
    function getDelegatorNonce(address delegator) external view returns (uint256) {
        return Checkpoints.delegateStorage().nonces[delegator];
    }

    /// @inheritdoc IVotes
    function domainSeparatorV4() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_TYPEHASH,
                keccak256(bytes(IVotesToken(this).name())),
                keccak256(bytes(IVotesToken(this).version())),
                block.chainid,
                address(this)
            )
        );
    }

    /// @inheritdoc IVotes
    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external {
        // slither-disable-next-line timestamp
        require(block.timestamp <= expiry, "Signature expired");

        Checkpoints.DelegateStorage storage ds = Checkpoints.delegateStorage();
        address delegator = ECDSA.recover(
            ECDSA.toTypedDataHash(
                domainSeparatorV4(), keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry))
            ),
            v,
            r,
            s
        );

        require(nonce == ds.nonces[delegator], "Invalid nonce");

        ds.nonces[delegator]++;
        handleDelegation(delegator, delegatee);
    }

    /**
     * @notice clears the delegation of the sender
     */
    function clearDelegation() external {
        address currentDelegate = Checkpoints.delegates(msg.sender);

        // Ensure the caller has an active delegation
        require(currentDelegate != address(0), "Votes: No active delegation to clear");

        uint256 balance = IVotesToken(this).balanceOf(msg.sender);
        uint256 votes = getVotes(msg.sender);

        if (currentDelegate == msg.sender) {
            Checkpoints.moveDelegation(currentDelegate, address(0), votes > balance ? balance : votes);
        } else {
            Checkpoints.moveDelegation(currentDelegate, address(0), balance);
        }
        Checkpoints.clearDelegation(msg.sender);
    }

    /**
     * @dev internal function to transfer voting units from one account to another. This should be called by contracts inheriting this one after a transfer.
     * @param from the address to transfer voting units from
     * @param to the address to transfer voting units to
     * @param amount the amount of voting units to transfer
     */
    function transferVotingUnits(address from, address to, uint256 amount) internal {
        Checkpoints.transferVotingUnits(from, to, amount);
    }

    /**
     * @dev internal function to delegate voting units from one account to another. This should be called by contracts inheriting this one after a transfer.
     * @param delegator the address to delegate voting units from
     * @param delegatee the address to delegate voting units to
     */
    function handleDelegation(address delegator, address delegatee) internal {
        require(delegatee != address(0), "Votes: delegatee cannot be zero address");
        address oldDelegate = Checkpoints.delegates(delegator);
        Checkpoints.delegate(delegator, delegatee);
        Checkpoints.moveDelegation(oldDelegate, delegatee, IVotesToken(this).balanceOf(delegator));
    }
}
