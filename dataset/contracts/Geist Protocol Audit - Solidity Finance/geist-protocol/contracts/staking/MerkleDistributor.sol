// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.6;

import "../interfaces/IMultiFeeDistribution.sol";
import "../dependencies/openzeppelin/contracts/Ownable.sol";
import "../dependencies/openzeppelin/contracts/SafeMath.sol";


contract MerkleDistributor is Ownable {
    using SafeMath for uint256;

    struct ClaimRecord {
        bytes32 merkleRoot;
        uint256 validUntil;
        uint256 total;
        uint256 claimed;
    }

    uint256 public immutable maxMintableTokens;
    uint256 public mintedTokens;
    uint256 public reservedTokens;
    uint256 public immutable startTime;
    uint256 public constant duration = 86400 * 365;
    uint256 public constant minDuration = 86400 * 7;

    IMultiFeeDistribution public rewardMinter;

    ClaimRecord[] public claims;

    event Claimed(
        address indexed account,
        uint256 indexed merkleIndex,
        uint256 index,
        uint256 amount,
        address receiver
    );

    // This is a packed array of booleans.
    mapping(uint256 => mapping(uint256 => uint256)) private claimedBitMap;

    constructor(IMultiFeeDistribution _rewardMinter, uint256 _maxMintable) Ownable() {
        rewardMinter = _rewardMinter;
        maxMintableTokens = _maxMintable;
        startTime = block.timestamp;
    }

    function mintableBalance() public view returns (uint256) {
        uint elapsedTime = block.timestamp.sub(startTime);
        if (elapsedTime > duration) elapsedTime = duration;
        return maxMintableTokens.mul(elapsedTime).div(duration).sub(mintedTokens).sub(reservedTokens);
    }

    function addClaimRecord(bytes32 _root, uint256 _duration, uint256 _total) external onlyOwner {
        require(_duration >= minDuration);
        uint mintable = mintableBalance();
        require(mintable >= _total);

        claims.push(ClaimRecord({
            merkleRoot: _root,
            validUntil: block.timestamp + _duration,
            total: _total,
            claimed: 0
        }));
        reservedTokens = reservedTokens.add(_total);

    }

    function releaseExpiredClaimReserves(uint256[] calldata _claimIndexes) external {
        for (uint256 i = 0; i < _claimIndexes.length; i++) {
            ClaimRecord storage c = claims[_claimIndexes[i]];
            require(block.timestamp > c.validUntil, 'MerkleDistributor: Drop still active.');
            reservedTokens = reservedTokens.sub(c.total.sub(c.claimed));
            c.total = 0;
            c.claimed = 0;
        }
    }

    function isClaimed(uint256 _claimIndex, uint256 _index) public view returns (bool) {
        uint256 claimedWordIndex = _index / 256;
        uint256 claimedBitIndex = _index % 256;
        uint256 claimedWord = claimedBitMap[_claimIndex][claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 _claimIndex, uint256 _index) private {
        uint256 claimedWordIndex = _index / 256;
        uint256 claimedBitIndex = _index % 256;
        claimedBitMap[_claimIndex][claimedWordIndex] = claimedBitMap[_claimIndex][claimedWordIndex] | (1 << claimedBitIndex);
    }

    function claim(
        uint256 _claimIndex,
        uint256 _index,
        uint256 _amount,
        address _receiver,
        bytes32[] calldata _merkleProof
    ) external {
        require(_claimIndex < claims.length, 'MerkleDistributor: Invalid merkleIndex');
        require(!isClaimed(_claimIndex, _index), 'MerkleDistributor: Drop already claimed.');

        ClaimRecord storage c = claims[_claimIndex];
        require(c.validUntil > block.timestamp, 'MerkleDistributor: Drop has expired.');

        c.claimed = c.claimed.add(_amount);
        require(c.total >= c.claimed, 'MerkleDistributor: Exceeds allocated total for drop.');

        reservedTokens = reservedTokens.sub(_amount);
        mintedTokens = mintedTokens.add(_amount);

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(_index, msg.sender, _amount));
        require(verify(_merkleProof, c.merkleRoot, node), 'MerkleDistributor: Invalid proof.');

        // Mark it claimed and send the token.
        _setClaimed(_claimIndex, _index);
        rewardMinter.mint(_receiver, _amount, true);

        emit Claimed(msg.sender, _claimIndex, _index, _amount, _receiver);
    }

    function verify(bytes32[] calldata _proof, bytes32 _root, bytes32 _leaf) internal pure returns (bool) {
        bytes32 computedHash = _leaf;

        for (uint256 i = 0; i < _proof.length; i++) {
            bytes32 proofElement = _proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == _root;
    }

}
