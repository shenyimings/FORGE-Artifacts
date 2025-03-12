// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { ReentrancyGuard } from '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

interface IVLRadepie {
    function lockFor(uint256, address) external;
}

contract RadpieAirdrop is Ownable, Pausable, ReentrancyGuard {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ============ State Variables ============ */

    bytes32 public totalRewardMerkleRoot;
    uint256 public startVestingTime;
    uint256 public vestingPeriodCount;
    uint256 public intervals;

    mapping(address => uint256) private claimedAmount;

    IERC20 public reward;
    IVLRadepie public vlRDP;

    /* ============ Events ============ */

    event ClaimEvent(address account, uint256 amount, bool isLock);
    event VLRDPUpdated(address _newVlRDP, address _oldVlRDP);

    /* ============ Errors ============ */

    error NotStarted();
    error InvalidProof();

    /* ============ Constructor ============ */

    constructor(IERC20 _reward, address _vlRDP,  uint256 _startVestingTime, uint256 _vestingPeriodCount, uint256 _intervals, bytes32 _totalRewardMerkleRoot) {
        reward = _reward;
        totalRewardMerkleRoot = _totalRewardMerkleRoot;
        startVestingTime = _startVestingTime;
        vestingPeriodCount = _vestingPeriodCount;
        intervals = _intervals;
        vlRDP = IVLRadepie(_vlRDP);
    }

    /* ============ External Getters ============ */

    function getClaimed(address account) public view returns (uint256) {
        return claimedAmount[account];
    }

    function getClaimable(address account, uint256 totalAmount, bytes32[] calldata merkleProof) public view returns (uint256) {
        if (block.timestamp < startVestingTime) {
            return 0;
        }
        
        if (!verifyProof(account, totalAmount, merkleProof)) {
            return 0;
        }

        uint256 claimable =  _getClaimable(account, totalAmount);
        return claimable;
    }

    /* ============ External Functions ============ */

    function verifyProof(address account, uint256 amount,  bytes32[] calldata merkleProof) public view returns (bool) {
         bytes32 node = keccak256(abi.encodePacked(account, amount));
         return MerkleProof.verify(
                merkleProof,
                totalRewardMerkleRoot,
                node
        );
    }

    function claim(uint256 totalAmount, bytes32[] calldata merkleProof, bool isLock) external whenNotPaused nonReentrant {
        if (block.timestamp < startVestingTime) revert NotStarted();

        //Verify the merkle proof.
        if (!verifyProof(msg.sender, totalAmount, merkleProof)) revert InvalidProof();

        uint256 claimable = _getClaimable(msg.sender, totalAmount);

        // Mark it claimed and send the token.
        if (isLock) {
            reward.safeApprove(address(vlRDP), claimable);
            vlRDP.lockFor(claimable, msg.sender);
        } else {
            reward.safeTransfer(msg.sender, claimable);
        }
        uint256 userClaimedAmount = claimedAmount[msg.sender];
        claimedAmount[msg.sender] = userClaimedAmount + claimable;
        emit ClaimEvent(msg.sender, claimable, isLock);
    }

    /* ============ Internal Functions ============ */

    function _getClaimable(address account, uint256 totalAmount) internal view returns (uint256) {
        uint256 claimed = getClaimed(account);
        if (claimed >= totalAmount) {
            return 0;
        }

        uint256 vested = (totalAmount * 30 / 100) + (totalAmount * 70 / 100) * ((block.timestamp - startVestingTime) / intervals) / (vestingPeriodCount);
        if (vested > totalAmount) {
            return totalAmount - claimed;
        }

        return vested - claimed;
    }

    /* ============ Admin functions ============ */

    function setVlRDP(address _vlRDP) external onlyOwner
    {
        address oldVlRDP = address(vlRDP);
        vlRDP = IVLRadepie(_vlRDP);
        emit VLRDPUpdated(address(vlRDP), oldVlRDP);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw() external onlyOwner whenPaused {
        reward.safeTransfer(owner(), reward.balanceOf((address(this))));
    }
}
