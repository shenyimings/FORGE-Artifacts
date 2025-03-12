// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IRewardPool.sol";
import "../access/SpoolAccessControllable.sol";

contract RewardPool is IRewardPool, SpoolAccessControllable {
    using SafeERC20 for IERC20;

    mapping(uint256 => bytes32) public roots;

    mapping(bytes32 => bool) public isLeafClaimed;

    mapping(address => mapping(address => mapping(address => uint256))) public rewardsClaimed;

    uint256 public cycleCount;

    bool public allowUpdates;

    constructor(ISpoolAccessControl accessControl, bool allowUpdates_) SpoolAccessControllable(accessControl) {
        allowUpdates = allowUpdates_;
    }

    function addTreeRoot(bytes32 root) external onlyRole(ROLE_REWARD_POOL_ADMIN, msg.sender) {
        cycleCount++;
        roots[cycleCount] = root;

        emit PoolRootAdded(cycleCount);
    }

    function updateTreeRoot(bytes32 root, uint256 cycle) external onlyRole(ROLE_REWARD_POOL_ADMIN, msg.sender) {
        if (!allowUpdates) {
            revert RootUpdatesNotAllowed();
        }

        if (cycle > cycleCount) {
            revert InvalidCycle();
        }

        roots[cycle] = root;

        emit PoolRootUpdated(cycle);
    }

    function claim(ClaimRequest[] calldata data) public {
        for (uint256 i; i < data.length; ++i) {
            bytes32 leaf = _getLeaf(data[i], msg.sender);
            if (isLeafClaimed[leaf]) {
                revert ProofAlreadyClaimed(i);
            }

            if (!_verify(data[i], leaf)) {
                revert InvalidProof(i);
            }

            isLeafClaimed[leaf] = true;

            uint256 alreadyClaimed = rewardsClaimed[msg.sender][data[i].smartVault][data[i].token];
            uint256 toClaim = data[i].rewardsTotal - alreadyClaimed;
            rewardsClaimed[msg.sender][data[i].smartVault][data[i].token] += toClaim;

            IERC20(data[i].token).safeTransfer(msg.sender, toClaim);

            emit RewardsClaimed(msg.sender, data[i].smartVault, data[i].token, data[i].cycle, toClaim);
        }
    }

    function verify(ClaimRequest memory data, address user) public view returns (bool) {
        return _verify(data, _getLeaf(data, user));
    }

    function _verify(ClaimRequest memory data, bytes32 leaf) internal view returns (bool) {
        return MerkleProof.verify(data.proof, roots[data.cycle], leaf);
    }

    function _getLeaf(ClaimRequest memory data, address user) internal pure returns (bytes32) {
        return keccak256(
            bytes.concat(keccak256(abi.encode(user, data.cycle, data.smartVault, data.token, data.rewardsTotal)))
        );
    }
}
