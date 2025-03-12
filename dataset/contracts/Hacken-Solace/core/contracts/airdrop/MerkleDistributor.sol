// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../interfaces/airdrop/IMerkleDistributor.sol";
import "../utils/Governable.sol";
// import "hardhat/console.sol";

contract MerkleDistributor is IMerkleDistributor, Governable {
    address public immutable override token; // Airdrop token
    bytes32 public immutable override merkleRoot; // Merkle root

    mapping(address => bool) private hasUserClaimed; // Mapping of who has claimed airdrop.

    error AlreadyClaimed(); // Thrown if address has already claimed.
    error NotInMerkle(); // Thrown if address/amount not in Merkle tree.
    error FailedClaimTransfer(address user, uint256 amount); // Thrown if transfer of airdrop tokens when calling claim() fails.
    error FailedGovernorRecover(uint256 amount); // Thrown if transfer of airdrop tokens when calling governorRecoverAirdropTokens() fails.

    /**
     * @notice Constructs `Solace Cover Product`.
     * @param token_ The address of the airdrop token.
     * @param merkleRoot_ Merkle root.
     * @param governance_ The address of the governor.
     */
    constructor(
        address token_, 
        bytes32 merkleRoot_,
        address governance_
    ) 
        public 
        Governable(governance_)
    {
        token = token_;
        merkleRoot = merkleRoot_;
    }

    /**
     * @notice Returns true if address has claimed, false if not.
     * @param user Address of user to check.
     */
    function hasClaimed(address user) public view override returns (bool) {
        return hasUserClaimed[user];
    }

    /**
     * @notice Airdrop claim function.
     * @dev Expect frontend to use offchain script to compute merkleProof and amount parameters, given set merkle tree
     * @param user Address of airdrop claimer.
     * @param amount Amount of airdrop to claim.
     * @param merkleProof Merkle proof or Merkle path, to calculate merkle root given this node - (user, amount).
     */
    function claim(address user, uint256 amount, bytes32[] calldata merkleProof) external override {
        if (hasUserClaimed[user]) revert AlreadyClaimed();

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(user, amount));
        if (!MerkleProof.verify(merkleProof, merkleRoot, node)) revert NotInMerkle();

        // Mark it claimed and send the token.
        hasUserClaimed[user] = true;

        if (!IERC20(token).transfer(user, amount)) revert FailedClaimTransfer(user, amount); // Can there be a bug here if transfer returns success despite not actually transferring tokens?
        emit Claimed(user, amount);
    }

    /**
     * @notice Governance-only function to recover airdrop tokens from this smart contract,
     * In the case that a significant amount of airdrop tokens are not claimed
     */
    function governorRecoverAirdropTokens() external override onlyGovernance {
        address governance = this.governance(); // Inefficient here, governance should be an internal variable and not a private variable
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (!IERC20(token).transfer(governance, balance)) revert FailedGovernorRecover(balance);
        emit GovernorRecoverAirdropTokens(balance);
    }
}

// Useful resources

// Modified from https://github.com/Uniswap/merkle-distributor/blob/master/contracts/MerkleDistributor.sol
// https://github.com/Anish-Agnihotri/merkle-airdrop-starter/blob/master/contracts/src/MerkleClaimERC20.sol

// Use Custom errors - https://blog.soliditylang.org/2021/04/21/custom-errors/ - instead of require strings
// Cheaper in deploy and runtime costs, able to convey dynamic information