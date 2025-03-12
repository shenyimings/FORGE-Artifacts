// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

// Allows anyone to claim a token if they exist in a merkle root.
interface IMerkleDistributor {
    /// @notice event is triggered whenever a call to `claim` succeeds
    event Claimed(uint256 index, address account, uint256 amount);

    /// @return escrow for tokens claimed
    function rewardEscrow() external view returns (address);

    /// @return token to be distributed (KWENTA)
    function token() external view returns (address);

    /// @return contract that initiates claim from L1 (called by address attempting to claim)
    function controlL2MerkleDistributor() external view returns (address);

    // @return the merkle root of the merkle tree containing account balances available to claim
    function merkleRoot() external view returns (bytes32);

    /// @notice owner can set address of ControlL2MerkleDistributor
    /// @dev this function must be called after (1) this contract has been deployed and
    /// (2) ControlL2MerkleDistributor has been deployed (which requires this contract's
    /// deployment address as input in the constructor)
    /// @param _controlL2MerkleDistributor: address of contract that initiates claim from L1
    function setControlL2MerkleDistributor(address _controlL2MerkleDistributor)
        external;

    /// @notice determine if indexed claim has been claimed
    /// @param index: used for claim managment
    /// @return true if indexed claim has been claimed
    function isClaimed(uint256 index) external view returns (bool);

    /// @notice attempt to claim as `account` and escrow KWENTA for `account`
    /// @param index: used for merkle tree managment and verification
    /// @param account: address used for escrow entry
    /// @param amount: $KWENTA amount to be escrowed
    /// @param merkleProof: off-chain generated proof of merkle tree inclusion
    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external;

    /// @notice attempt to claim as `account` and escrow KWENTA for `destAccount`
    /// @param index: used for merkle tree managment and verification
    /// @param account: address that initiated claim and designated `destAccount`
    /// @param destAccount: address used for escrow entry
    /// @param amount: $KWENTA amount to be escrowed
    /// @param merkleProof: off-chain generated proof of merkle tree inclusion
    function claimToAddress(
        uint256 index,
        address account,
        address destAccount,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external;
}
