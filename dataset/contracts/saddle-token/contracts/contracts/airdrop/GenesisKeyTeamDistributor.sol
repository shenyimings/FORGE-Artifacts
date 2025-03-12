//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../interface/IGenesisKeyTeamDistributor.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// From: https://github.com/Uniswap/merkle-distributor/blob/master/contracts/MerkleDistributor.sol

interface IGkTeam {
    function teamClaim(address recipient) external returns (bool);
}

contract GenesisKeyTeamDistributor is IGenesisKeyTeamDistributor {
    address public immutable override gkTeam;
    bytes32 public override merkleRoot;
    address public override owner;

    // This is a packed array of booleans.
    mapping(uint256 => uint256) private claimedBitMap;
    mapping(address => bool) private addressClaimed;

    constructor(address gkTeam_) {
        gkTeam = gkTeam_;
        owner = msg.sender;
    }

    function transferOwnership(address _newOwner) external {
        require(msg.sender == owner, "!auth");
        owner = _newOwner;
    }

    function changeMerkleRoot(bytes32 _newRoot) external {
        require(msg.sender == owner, "!auth");
        merkleRoot = _newRoot;
    }

    function claim(
        uint256 index,
        address account,
        uint256 tokenId,
        bytes32[] calldata merkleProof
    ) external payable override {
        require(msg.sender == account);
        require(!addressClaimed[account], "GKTeamDistributor: Drop already claimed.");

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, tokenId));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), "GKTeamDistributor: Invalid proof.");

        // Mark it claimed and send the token.
        addressClaimed[account] = true;
        require(IGkTeam(gkTeam).teamClaim(account), "GKTeamDistributor: No team keys available");

        emit Claimed(index, account, tokenId);
    }
}
