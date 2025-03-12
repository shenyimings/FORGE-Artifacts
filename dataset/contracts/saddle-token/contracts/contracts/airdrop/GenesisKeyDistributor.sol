//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../interface/IGenesisKeyDistributor.sol";
import "../interface/IGenesisKey.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// From: https://github.com/Uniswap/merkle-distributor/blob/master/contracts/MerkleDistributor.sol

contract GenesisKeyDistributor is IGenesisKeyDistributor {
    address public immutable override genesisKey;
    bytes32 public immutable override merkleRoot;
    uint256 public immutable override ethAmount;

    // This is a packed array of booleans.
    mapping(uint256 => uint256) private claimedBitMap;

    constructor(address genesisKey_, bytes32 merkleRoot_, uint256 ethAmount_) {
        genesisKey = genesisKey_;
        merkleRoot = merkleRoot_;
        ethAmount = ethAmount_;
    }

    function isClaimed(uint256 index) public view override returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    function claim(
        uint256 index,
        address account,
        uint256 tokenId,
        bytes32[] calldata merkleProof
    ) external payable override {
        require(msg.sender == account);
        require(msg.value == ethAmount);
        require(!isClaimed(index), "GenesisKeyDistributor: Drop already claimed.");

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, tokenId));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), "GenesisKeyDistributor: Invalid proof.");

        // Mark it claimed and send the token.
        _setClaimed(index);
        IGenesisKey(genesisKey).claimKey{ value: ethAmount }(account, ethAmount);

        emit Claimed(index, account, tokenId);
    }
}
