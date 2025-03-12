//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// Allows anyone to claim a token if they exist in a merkle root.
interface IGenesisKeyDistributor {
    // Returns the address of the genesisKey contract.
    function genesisKey() external view returns (address);

    // Returns the merkle root of the merkle tree containing account balances available to claim.
    function merkleRoot() external view returns (bytes32);

    // Returns the profile auction contract address.
    function ethAmount() external view returns (uint256);

    // Returns true if the index has been marked claimed.
    function isClaimed(uint256 index) external view returns (bool);

    // Claim the given amount of the token to the given address. Reverts if the inputs are invalid.
    function claim(uint256 index, address account, uint256 tokenId, bytes32[] calldata merkleProof) external payable;

    // This event is triggered whenever a call to #claim succeeds.
    event Claimed(uint256 index, address account, uint256 tokenId);
}
