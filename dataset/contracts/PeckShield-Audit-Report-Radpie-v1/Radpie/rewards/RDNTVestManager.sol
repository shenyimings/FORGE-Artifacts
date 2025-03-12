// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title A contract for managing RDNT vesting schedules and claiming vested RDNT for users
/// @author Radpie Team

/// Entitled RDNT are the RDNT amount that Radiant Staking claim from Radiant Capital, waiting to vest
/// Vestable RDNT are the RDNT amount that Radiant Staking has started claiming

/// The flow of RDNT vesting flow.
/// 1. RDNTVestManager.nextVestedTime is the RDNT vested time for all Radpie user they start vesting their Entitled RDNT at anytime.  (timestamp: T1 - x, 0 days < x < 10 days)
/// 2. RDNTRewardManager.startVestingAll call to make RadianStaking request vesting all current claimable RDNT on Radiant.            (timestamp: T1)
/// 3. RDNTRewardManager.collectVestedRDNTAll to make RadianStaking claim all vesterd RDNT and trasnfer to RDNTVestManager            (timestamp: T1 + 90)
/// 4. User can claim their vested RDNT from RDNTVestManager                                                                          (after timestamp: T1 + 90 )
/// vesting day of RDNT for Radpie user will be:   90 < RDNT vest time < 90 + x, (0 days < x < 10 days)

contract RDNTVestManager is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    /* ============ State Variables ============ */

    using SafeERC20 for IERC20;

    address public rdntToken; // The address of the RDNT token contract
    address public rewardManager;

    struct VestingSchedule {
        uint256 amount;
        uint256 endTime;
    }

    mapping(address => VestingSchedule[]) public vestingSchedules; // User's RDNT vesting schedules
    uint256 public vestingShceduleCleanUpThreShold;

    /* ============ Error ============ */

    error NotAllowZeroAddress();
    error NotAuthorized();
    error InvalidIndex();

    /* ============ Events ============ */

    event VestingScheduled(address indexed user, uint256 amount, uint256 endTime);
    event RDNTClaimed(address indexed user, uint256 amount);

    /* ============ Constructor ============ */

    function __RDNTVestManager_init(address _rdntToken, address _rewardManager) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        if (_rdntToken == address(0)) revert NotAllowZeroAddress();
        if (_rewardManager == address(0)) revert NotAllowZeroAddress();
        rdntToken = _rdntToken;
        rewardManager = _rewardManager;
        vestingShceduleCleanUpThreShold = 5;
    }

    /* ============ Modifiers ============ */

    modifier onlyRewardManager() {
        if (msg.sender != address(rewardManager)) revert NotAuthorized();
        _;
    }

    /* ============ External Functions ============ */

    /// @notice Schedule a user's RDNT vesting
    /// @param _amount The amount of RDNT to vest
    function scheduleVesting(
        address _for,
        uint256 _amount,
        uint256 _endTime
    ) external nonReentrant onlyRewardManager {
        vestingSchedules[_for].push(VestingSchedule(_amount, _endTime));

        emit VestingScheduled(_for, _amount, _endTime);
    }

    /// @notice Claim vested RDNT
    function claim() external nonReentrant returns (uint256) {
        VestingSchedule[] storage schedules = vestingSchedules[msg.sender];
        uint256 claimedVestedSchedules;
        uint256 totalClaimable;

        for (uint256 i = 0; i < schedules.length; i++) {
            VestingSchedule storage schedule = schedules[i];

            if (block.timestamp >= schedule.endTime) {
                claimedVestedSchedules++;
                totalClaimable += schedule.amount;
                schedule.amount = 0;
            }
        }

        if (totalClaimable > 0) {
            IERC20(rdntToken).safeTransfer(msg.sender, totalClaimable);
            emit RDNTClaimed(msg.sender, totalClaimable);
        }

        if (
            claimedVestedSchedules > 0 && claimedVestedSchedules >= vestingShceduleCleanUpThreShold
        ) {
            for (uint256 i = 0; i < schedules.length - claimedVestedSchedules; i++) {
                schedules[i] = schedules[i + claimedVestedSchedules];
            }

            while (claimedVestedSchedules > 0) {
                schedules.pop();
                claimedVestedSchedules--;
            }
        }

        return totalClaimable;
    }

    /// @notice Get all vested amounts and end times for a user

    function getAllVestingInfo(
        address _user
    )
        external
        view
        returns (
            VestingSchedule[] memory,
            uint256 totalRDNTRewards,
            uint256 totalVested,
            uint256 totalVesting
        )
    {
        VestingSchedule[] storage schedules = vestingSchedules[_user];
        uint256 tempCount;
        for (uint256 i = 0; i < schedules.length; i++) {
            if (block.timestamp < schedules[i].endTime) {
                tempCount++;
            }
        }

        VestingSchedule[] memory _vestingSchedules = new VestingSchedule[](tempCount);
        uint256 j = 0;

        for (uint256 i = 0; i < schedules.length; i++) {
            VestingSchedule storage currentSchedule = schedules[i];
            totalRDNTRewards += currentSchedule.amount;
            if (block.timestamp > currentSchedule.endTime) {
                totalVested += currentSchedule.amount;
            } else {
                totalVesting += currentSchedule.amount;
                _vestingSchedules[j] = currentSchedule;
                j++;
            }
        }
        return (_vestingSchedules, totalRDNTRewards, totalVested, totalVesting);
    }

    /* ============ Admin Functions ============ */

    /// @notice Withdraw any remaining RDNT tokens in the contract (admin function)
    /// @param _amount The amount of RDNT tokens to withdraw
    function withdrawRDNT(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than zero");
        IERC20(rdntToken).transfer(msg.sender, _amount);
    }

    function updateVestingScheduleCleanUpThreshold(uint256 _newThreShold) external onlyOwner {
        require(_newThreShold > 0, "New threshold must be greater than zero");
        vestingShceduleCleanUpThreShold = _newThreShold;
    }
}
