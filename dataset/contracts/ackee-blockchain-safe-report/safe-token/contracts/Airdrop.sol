// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

import "./vendor/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./vendor/@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/ModuleManager.sol";
import "./VestingPool.sol";

/// @title Airdrop contract
/// @author Richard Meissner - @rmeissner
contract Airdrop is VestingPool {
    // Root of the Merkle tree
    bytes32 public root;
    // Time until which the airdrop can be redeemed
    uint64 public immutable redeemDeadline;

    constructor(
        address _token,
        address _manager,
        uint64 _redeemDeadline
    ) VestingPool(_token, _manager) {
        redeemDeadline = _redeemDeadline;
    }

    /// @notice Initialize the airdrop with `_root` as the Merkle root.
    /// @dev This can only be called once
    /// @param _root The Merkle root that should be set for this contract
    function initializeRoot(bytes32 _root) public onlyPoolManager {
        require(root == bytes32(0), "State root already initialized");
        root = _root;
    }

    /// @notice Creates a vesting authorized by the Merkle proof.
    /// @dev It is required that the pool has enough tokens available
    /// @dev Vesting will be created for msg.sender
    /// @param curveType Type of the curve that should be used for the vesting
    /// @param durationWeeks The duration of the vesting in weeks
    /// @param startDate The date when the vesting should be started (can be in the past)
    /// @param amount Amount of tokens that should be vested in atoms
    /// @param proof Proof to redeem tokens
    function redeem(
        uint8 curveType,
        uint16 durationWeeks,
        uint64 startDate,
        uint128 amount,
        bytes32[] calldata proof
    ) external {
        require(block.timestamp <= redeemDeadline, "Deadline to redeem vesting has been exceeded");
        require(root != bytes32(0), "State root not initialized");
        // This call will fail if the vesting was already created
        bytes32 vestingId = _addVesting(msg.sender, curveType, false, durationWeeks, startDate, amount);
        require(MerkleProof.verify(proof, root, vestingId), "Invalid merkle proof");
    }

    /// @notice Claim `tokensToClaim` tokens from vesting `vestingId` and transfer them to the `beneficiary`.
    /// @dev This can only be called by the owner of the vesting
    /// @dev Beneficiary cannot be the 0-address
    /// @dev This will trigger a transfer of tokens via a module transaction
    /// @param vestingId Id of the vesting from which the tokens should be claimed
    /// @param beneficiary Account that should receive the claimed tokens
    /// @param tokensToClaim Amount of tokens to claim in atoms or max uint128 to claim all available
    function claimVestedTokensViaModule(
        bytes32 vestingId,
        address beneficiary,
        uint128 tokensToClaim
    ) public {
        uint128 tokensClaimed = updateClaimedTokens(vestingId, beneficiary, tokensToClaim);
        // Approve pool manager to transfer tokens on behalf of the pool
        require(IERC20(token).approve(poolManager, tokensClaimed), "Could not approve tokens");
        // Check state prior to transfer
        uint256 balancePoolBefore = IERC20(token).balanceOf(address(this));
        uint256 balanceBeneficiaryBefore = IERC20(token).balanceOf(beneficiary);
        // Build transfer data to call token contract via the pool manager
        bytes memory transferData = abi.encodeWithSignature(
            "transferFrom(address,address,uint256)",
            address(this),
            beneficiary,
            tokensClaimed
        );
        // Trigger transfer of tokens from this pool to the beneficiary via the pool manager as a module transaction
        require(ModuleManager(poolManager).execTransactionFromModule(token, 0, transferData, 0), "Module transaction failed");
        // Set allowance to 0 to avoid any left over allowance. (Note: this should be impossible for normal ERC20 tokens)
        require(IERC20(token).approve(poolManager, 0), "Could not set token allowance to 0");
        // Check state after the transfer
        uint256 balancePoolAfter = IERC20(token).balanceOf(address(this));
        uint256 balanceBeneficiaryAfter = IERC20(token).balanceOf(beneficiary);
        require(balancePoolAfter == balancePoolBefore - tokensClaimed, "Could not deduct tokens from pool");
        require(balanceBeneficiaryAfter == balanceBeneficiaryBefore + tokensClaimed, "Could not add tokens to beneficiary");
    }

    /// @notice Claims all tokens that have not been redeemed before `redeemDeadline`
    /// @dev Can only be called after `redeemDeadline` has been reached.
    /// @param beneficiary Account that should receive the claimed tokens
    function claimUnusedTokens(address beneficiary) external onlyPoolManager {
        require(block.timestamp > redeemDeadline, "Tokens can still be redeemed");
        uint256 unusedTokens = tokensAvailableForVesting();
        require(unusedTokens > 0, "No tokens to claim");
        require(IERC20(token).transfer(beneficiary, unusedTokens), "Token transfer failed");
    }

    /// @dev This method cannot be called on this contract
    function addVesting(
        address,
        uint8,
        bool,
        uint16,
        uint64,
        uint128
    ) public pure override {
        revert("This method is not available for this contract");
    }
}
