// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

import "./vendor/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./vendor/@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./VestingPool.sol";

// TODO: add possibility to claim tokens when airdrop is expired
/// @title Airdrop contract
/// @author Richard Meissner - @rmeissner
contract Airdrop is VestingPool {
    bytes32 public root;

    constructor(address token, address manager) VestingPool(token, manager) {}

    /// @notice Intialize the airdrop with `_root` as the Merkle root.
    /// @dev This can only be called once
    /// @param _root The Merkle root that should be set for this contract
    function initializeRoot(bytes32 _root) public onlyPoolManager {
        require(root == bytes32(0), "State root already initialized");
        root = _root;
    }

    // TODO: add redeem multiple for same account
    // TODO: add expiration time
    /// @notice Immediatelly redeems `amount` tokens and creates a vesting for the same amount.
    /// @dev It is required that the pool has enough tokens available
    /// @dev This will trigger a transfer of tokens
    /// @param account The account for which the vesting is created
    /// @param curveType Type of the curve that should be used for the vesting
    /// @param durationWeeks The duration of the vesting in weeks
    /// @param startDate The date when the vesting should be started (can be in the past)
    /// @param amount Amount of tokens that should be vested in atoms
    /// @param proof Proof to redeem tokens
    function redeem(
        address account,
        uint8 curveType,
        uint16 durationWeeks,
        uint64 startDate,
        uint128 amount,
        bytes32[] calldata proof
    ) external {
        // TODO: only account be able to claim (e.g. require(account == msg.sender))
        require(root != bytes32(0), "State root not initialized");
        // Add vesting will fail if the vesting was already created
        bytes32 vestingId = _addVesting(account, curveType, false, durationWeeks, startDate, amount);
        require(MerkleProof.verify(proof, root, vestingId), "Invalid merkle proof");
        // TODO: remove, this can be achieved via an additional vesting
        require(IERC20(token).transfer(account, amount), "Could not transfer token");
    }

    /// @notice Calculate the amount of tokens available for new vestings.
    /// @dev This value changes when more tokens are deposited to this contract
    /// @dev The value is halfed as the same amount vested is also immediately redeemed
    /// @return Amount of tokens that can be used for new vestings.
    function tokensAvailableForVesting() public view override returns (uint256) {
        // TODO: adjust when additional transfer is removed
        return (IERC20(token).balanceOf(address(this)) - totalTokensInVesting) / 2;
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
