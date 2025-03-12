// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/IMerkleDistributor.sol";

contract MerkleDistributor is IMerkleDistributor, Ownable {
    // Token to be claimed
    address public immutable override token;
    bytes32 public immutable override merkleRoot;

    // This is a packed array of booleans
    mapping(uint256 => uint256) private claimedBitMap;

    // Lock timestamp used to allow/disallow claim() and recover()
    uint256 public immutable lockTime;

    /**
     * @dev validate and set required parameters
     * @param token_ token to be claimed, must be non-zero
     * @param merkleRoot_ merkle root, must be non-zero
     * @param lockTime_ timestamp used for claim() and recover(), must be in the future
     */
    constructor(address token_, bytes32 merkleRoot_, uint256 lockTime_) {
        require(token_ != address(0), "Token must be non-zero address");
        require(merkleRoot_ != bytes32(0), "Merkle root must be non-zero");
        require(block.timestamp < lockTime_, "Lock time must be in the future");
        token = token_;
        merkleRoot = merkleRoot_;
        lockTime = lockTime_;
    }

    /**
     * @dev checks whether an index have been already claimed
     * @param index index to be checked
     * @return boolean value of the claim status
     */
    function isClaimed(uint256 index) public view override returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    /**
     * @dev mark the index as claimed in a gas-efficient way
     * @param index index to be marked
     */
    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    /**
     * @dev verifies the parameters and transfers the tokens if not yet claimed
     * @param index index used for claiming
     * @param account wallet eligible for the claim
     * @param amount amount of tokens to be claimed
     */
    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external override {
        // Allow claiming only before the lock time
        require(block.timestamp <= lockTime, "MerkleDistributor: Cannot claim after lock time");

        require(!isClaimed(index), "MerkleDistributor: Drop already claimed");

        // Verify the merkle proof
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "MerkleDistributor: Invalid proof"
        );

        // Mark it claimed and transfer the tokens
        _setClaimed(index);
        require(IERC20(token).transfer(account, amount), "MerkleDistributor: Transfer failed");

        emit Claimed(index, account, amount);
    }

    /**
     * @dev recovers remaining tokens, but only when after lockTime timestamp
     * @param amount amount of tokens to be recovered
     */
    function recover(uint256 amount) external onlyOwner {
        require(
            block.timestamp > lockTime,
            "MerkleDistributor: Cannot recover the tokens before lock time"
        );

        require(IERC20(token).transfer(owner(), amount), "MerkleDistributor: Recovery failed");

        emit Recovered(amount);
    }

    event Recovered(uint256 amount);
}
