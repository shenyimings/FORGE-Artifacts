// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/tokenomics/IAirdropClaiming.sol";

import "../../libraries/MerkleProof.sol";

contract AirdropClaiming is IAirdropClaiming, Ownable {
    using SafeERC20 for IERC20;
    using MerkleProof for MerkleProof.Proof;

    bytes32 public override merkleRoot;

    IERC20 public immutable override token;
    uint256 public immutable override endsAt;
    address public immutable override refundAddress;

    uint256 public override claimed;
    mapping(address => uint256) public override claimedBy;

    constructor(address _token, uint256 _endsAt, address _refundAddress) {
        token = IERC20(_token);
        endsAt = _endsAt;
        refundAddress = _refundAddress;
    }

    function initializeMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        require(merkleRoot == bytes32(0), "merkle root already set");
        merkleRoot = _merkleRoot;
        emit MerkleRootInitialized(_merkleRoot);
    }

    function claim(
        address claimer,
        uint256 amount,
        MerkleProof.Proof calldata proof
    ) external override {
        require(merkleRoot != bytes32(0), "merkle root not set");
        require(block.timestamp < endsAt, "airdrop has ended");
        require(claimedBy[claimer] == 0, "already claimed");

        bytes32 node = keccak256(abi.encodePacked(claimer, amount));
        require(proof.isValid(node, merkleRoot), "invalid proof");

        token.safeTransfer(claimer, amount);

        claimed += amount;
        claimedBy[claimer] = amount;
        emit Claimed(claimer, amount);
    }

    function refundNonClaimed() external override {
        require(block.timestamp >= endsAt, "airdrop has not ended");

        uint256 refundAmount = token.balanceOf(address(this));

        token.safeTransfer(refundAddress, refundAmount);

        emit Refunded(refundAmount);
    }
}
