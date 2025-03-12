// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.8.0 <0.9.0;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";
import "openzeppelin-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import "./AbraStaking.sol";

/**
 * @dev The purpose of this contract is to allow for a linear vesting schedule through locking tokens. 
 * A specified amount of tokens will be divided into portions that are locked such that the lock duration increases 
 * incrementally with each lock until the final portion is locked for the maximum lock duration.
 * 
 * The vesting contract is tokenized, meaning that future unlocks can be shared between multiple participants.
 * 
 * All voting rights are delegated to the contract owner.
 */
contract AbraVesting is Ownable2StepUpgradeable, ERC20Upgradeable, UUPSUpgradeable {

    using SafeERC20 for IERC20;

    event Harvest(address indexed user, uint256 reward);
    event Distributed(uint256 reward);
    event Claimed(uint256 amount);

    uint256 public constant TOTAL_SUPPLY = 1e6;

    // vesting params
    IERC20 public $abra;
    AbraStaking public $abraStaking;
    uint256 public $totalLocked;
    uint32 public $cooldownDuration;
    uint32 public $lockPeriodDuration;
    uint256 public $lockPeriodCount;
    uint256 public $lockedPerPeriod;

    // locking
    bool public $isVestingStarted;
    uint256 public $actualLockupId;
    uint256 public $lastAbraBalance;

    // distribution
    uint256 public $rewardPerToken;
    mapping(address => uint256) public $userRewardPerTokenPaid;
    mapping(address => uint256) public $rewards;

    // admin claim
    uint256 public $claimable;
    uint256 public $claimed;

    function initialize(
            string memory name_, 
            string memory symbol_, 
            address _abraStaking,
            uint256 _totalAmount,
            uint32 _cooldownDuration,
            uint32 _lockPeriodDuration,
            uint256 _lockPeriodCount) public initializer {
        __ERC20_init(name_, symbol_);
        __Ownable2Step_init();
        
        $abraStaking = AbraStaking(_abraStaking);
        $abra = ERC20($abraStaking.abra());
        uint256 minStakeDuration = $abraStaking.minStakeDuration();
        uint256 maxStakeDuration = $abraStaking.maxStakeDuration();

        uint256 vestingMinStakeDuration = _lockPeriodDuration + _cooldownDuration;
        uint256 vestingMaxStakeDuration = _lockPeriodDuration * _lockPeriodCount + _cooldownDuration;

        require(vestingMinStakeDuration >= minStakeDuration && vestingMaxStakeDuration <= maxStakeDuration, "Invalid lock duration");

        $cooldownDuration = _cooldownDuration;
        $lockPeriodDuration = _lockPeriodDuration;
        $lockPeriodCount = _lockPeriodCount;
        $lockedPerPeriod = _totalAmount / _lockPeriodCount;
        $totalLocked = $lockedPerPeriod * _lockPeriodCount;
    }

    //╔═══════════════════════════════════════════ LOCKING ═══════════════════════════════════════════╗

    function startVesting() external onlyOwner {
        require($isVestingStarted == false, "Already vesting");
        $isVestingStarted = true;

        uint _totalAmount = $totalLocked;
        AbraStaking _abraStaking = $abraStaking;
        IERC20 _abra = $abra;
        _abra.safeTransferFrom(msg.sender, address(this), _totalAmount);
        _abra.approve(address(_abraStaking), _totalAmount);

        uint _periodCount = $lockPeriodCount;
        uint _periodAmount = $lockedPerPeriod;
        uint _periodDuration = $lockPeriodDuration;
        uint _cooldown = $cooldownDuration;
        for (uint i = 1; i <= _periodCount; i++) {
            uint _duration = _cooldown + i * _periodDuration;
            _abraStaking.stake(_periodAmount, _duration);
        }

        uint _claimed = _abra.balanceOf(address(this));
        if (_claimed > 0) {
            _considerRewards(_claimed);
            $lastAbraBalance = _claimed;
        }

        _abraStaking.delegate(msg.sender);
        _mint(msg.sender, TOTAL_SUPPLY);
    }

    function unlockTokens() public {
        unlockTokens(type(uint256).max);
    }

    function unlockTokens(uint256 maxUnlockItems) public {
        uint _lockCount = $lockPeriodCount;
        uint _lockupId = $actualLockupId;
        if (_lockupId >= _lockCount) {
            return;
        }

        AbraStaking _abraStaking = $abraStaking;
        IERC20 _abra = $abra;
        uint _balanceBefore = $lastAbraBalance;
        uint _totalUnlocked = 0;
        uint _lockedPerPeriod = $lockedPerPeriod;
        for (uint unlockCount; unlockCount < maxUnlockItems && _lockupId < _lockCount; unlockCount++) {
            (uint128 _amount, uint128 _end, ) = _abraStaking.lockups(address(this), _lockupId);
            if (_end == 0) {
                _totalUnlocked += _lockedPerPeriod;
                _lockupId += 1;
                continue;
            }

            if (block.timestamp >= _end) {
                _abraStaking.unstake(_lockupId);
                _totalUnlocked += _amount;
                _lockupId += 1;
            } else {
                break;
            }
        }
        $actualLockupId = _lockupId;

        uint _balanceAfter = _abra.balanceOf(address(this));
        uint _claimed = _balanceAfter - _balanceBefore - _totalUnlocked;
        $lastAbraBalance = _balanceAfter;

        if (_totalUnlocked > 0) {
            _distribute(_totalUnlocked);
        }
        if (_claimed > 0) {
            _considerRewards(_claimed);
        }
    }

    function availableAmountToUnlock() public view returns (uint256 amount) {
        for (uint id = $actualLockupId; id < $lockPeriodCount; id++) {
            (uint128 _amount, uint128 _end, ) = $abraStaking.lockups(address(this), id);
            if (block.timestamp < _end) {
                break;
            }
            amount += $lockedPerPeriod;
        }
    }

    /**
     * @dev The new owner accepts the ownership transfer.
     */
    function acceptOwnership() public override {
        Ownable2StepUpgradeable.acceptOwnership();
        $abraStaking.delegate(msg.sender);
    }

    //╔═══════════════════════════════════════════ DISTRIBUTION ═══════════════════════════════════════════╗

    ///@notice see earned rewards for user
    function earned(address account) public view returns (uint256) {
        uint _rewardPerToken = $rewardPerToken + availableAmountToUnlock() * 1e18 / TOTAL_SUPPLY;
        return $rewards[account] + balanceOf(account) * (_rewardPerToken - $userRewardPerTokenPaid[account]) / 1e18;
    }

    ///@notice User harvest function
    function getReward() external {
        unlockTokens();
        uint _reward = earned(msg.sender);
        if (_reward > 0) {
            $userRewardPerTokenPaid[msg.sender] = $rewardPerToken;
            $rewards[msg.sender] = 0;
            emit Harvest(msg.sender, _reward);
            $abra.safeTransfer(msg.sender, _reward);
            $lastAbraBalance -= _reward;
        }
    }

    function updateReward(address account) private {
        if (account != address(0)) {
            uint256 _earned = earned(account);
            if (_earned > $rewards[account]) {
                $rewards[account] = _earned;
            }
            uint256 _rewardPerToken = $rewardPerToken;
            if (_rewardPerToken > $userRewardPerTokenPaid[account]) {
                $userRewardPerTokenPaid[account] = _rewardPerToken;
            }
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        unlockTokens();
        updateReward(from);
        updateReward(to);
    }

    function _distribute(uint reward) private {
        $rewardPerToken += reward * 1e18 / TOTAL_SUPPLY;
        emit Distributed(reward);
    }

    //╔═══════════════════════════════════════════ CLAIM ═══════════════════════════════════════════╗

    function claim() external onlyOwner {
        uint _amountToClaim = $claimable;

        uint _rewards = $abraStaking.previewRewards(address(this));
        if (_rewards > 0) {
            $abraStaking.collectRewards();
            _amountToClaim += _rewards;
        }

        emit Claimed(_amountToClaim);
        $abra.safeTransfer(msg.sender, _amountToClaim);

        $claimable = 0;
        $claimed += _amountToClaim;
        $lastAbraBalance -= _amountToClaim;
    }

    function previewClaim() external view returns (uint) {
        return $claimable + $abraStaking.previewRewards(address(this));
    }

    function _considerRewards(uint amount) private {
        $claimable += amount;
    }

    //╔═══════════════════════════════════════════ ADMIN ═══════════════════════════════════════════╗

    function _authorizeUpgrade(address) internal override onlyOwner {}

}