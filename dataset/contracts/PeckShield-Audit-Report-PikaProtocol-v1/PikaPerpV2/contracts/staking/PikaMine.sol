// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import '@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import './IVaultReward.sol';

/** @title VePika
    @notice Support locking PIKA to earn trading fee and token rewards. The longer the lock, the higher the weight
    the staker. The weight is also manifested as vePIKA balance.
 */
contract PikaMine is Initializable, ReentrancyGuardUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeCastUpgradeable for uint256;
    using SafeCastUpgradeable for int256;

    enum Lock { oneWeek, oneMonth, threeMonths, sixMonths, nineMonths, twelveMonths }

    struct UserInfo {
        uint256 depositAmount;
        uint256 lpAmount;
        uint256 lockedUntil;
        Lock lock;
    }

    uint256 public constant DAY = 1 days;
    uint256 public constant ONE_WEEK = 7 days;
    uint256 public constant TWO_WEEKS = ONE_WEEK * 2;
    uint256 public constant ONE_MONTH = 30 days;
    uint256 public constant THREE_MONTHS = ONE_MONTH * 3;
    uint256 public constant SIX_MONTHS = ONE_MONTH * 6;
    uint256 public constant NINE_MONTHS = ONE_MONTH * 9;
    uint256 public constant TWELVE_MONTHS = 365 days;
    uint256 public constant ONE = 1e18;

    // Pika token addr
    IERC20Upgradeable public pika;

    bool public unlockAll;

    uint256 public totalLpToken;
    uint256 public pikaTotalDeposits;

    address public owner;
    address public gov;
    // these can be pools for usdc vault fee reward, eth vault fee reward and token reward
    address[] public rewardPools;

    /// @notice user => depositId => UserInfo
    mapping (address => mapping (uint256 => UserInfo)) public userInfo;
    /// @notice user => depositId[]
    mapping (address => EnumerableSetUpgradeable.UintSet) private allUserDepositIds;
    /// @notice user => deposit index
    mapping (address => uint256) public currentId;

    event Deposit(address indexed user, uint256 indexed index, uint256 amount, uint256 lpAmount, Lock lock);
    event Withdraw(address indexed user, uint256 indexed index, uint256 amount, uint256 lpAmount);
    event SetOwner(address admin);
    event SetGov(address gov);

    function initialize(address _pika) external initializer {
        owner = msg.sender;
        gov = msg.sender;
        pika = IERC20Upgradeable(_pika);
    }

    function getAllUserDepositIds(address _user) public view returns (uint256[] memory) {
        return allUserDepositIds[_user].values();
    }

    function getLockBoost(Lock _lock) public pure returns (uint256 boost, uint256 timelock) {
        if (_lock == Lock.oneWeek) {
            // 5%
            return (5e16, ONE_WEEK);
        } else if (_lock == Lock.oneMonth) {
            // 10%
            return (10e16, ONE_MONTH);
        } else if (_lock == Lock.threeMonths) {
            // 20%
            return (20e16, THREE_MONTHS);
        } else if (_lock == Lock.sixMonths) {
            // 40%
            return (40e16, SIX_MONTHS);
        } else if (_lock == Lock.nineMonths) {
            // 65%
            return (65e16, NINE_MONTHS);
        } else if (_lock == Lock.twelveMonths) {
            // 100%
            return (100e16, TWELVE_MONTHS);
        } else {
            revert("Invalid lock value");
        }
    }

    function isUnlocked() public view returns(bool) {
        return unlockAll;
    }

    function deposit(uint256 _amount, Lock _lock) public updateRewards nonReentrant {
        pika.safeTransferFrom(msg.sender, address(this), _amount);

        (UserInfo storage user, uint256 depositId) = _addDeposit(msg.sender);
        (uint256 lockBoost, uint256 timelock) = getLockBoost(_lock);
        uint256 lpAmount = _amount * lockBoost / ONE;
        pikaTotalDeposits += _amount;
        totalLpToken += lpAmount;

        user.depositAmount = _amount;
        user.lpAmount = lpAmount;
        user.lockedUntil = block.timestamp + timelock;
        user.lock = _lock;

        emit Deposit(msg.sender, depositId, _amount, lpAmount, _lock);
    }

    function withdraw(uint256 _amount, uint256 _depositId) public updateRewards nonReentrant returns (bool) {
        UserInfo storage user = userInfo[msg.sender][_depositId];
        uint256 depositAmount = user.depositAmount;
        if (depositAmount == 0) return false;

        if (_amount > depositAmount) {
            _amount = depositAmount;
        }
        // anyone can withdraw if kill swith was used
        if (!unlockAll) {
            require(block.timestamp >= user.lockedUntil, "Position is still locked");
            uint256 unlockedAmount = unlocked(msg.sender, _depositId);
            if (_amount > unlockedAmount) {
                _amount = unlockedAmount;
            }
        }

        // Effects
        uint256 ratio = _amount * ONE / depositAmount;
        uint256 lpAmount = user.lpAmount * ratio / ONE;

        totalLpToken -= lpAmount;
        pikaTotalDeposits -= _amount;

        user.depositAmount -= _amount;
        user.lpAmount -= lpAmount;

        if (user.depositAmount == 0 && user.lpAmount == 0) {
            _removeDeposit(msg.sender, _depositId);
        }

        // Interactions
        pika.safeTransfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _depositId, _amount, lpAmount);

        return true;
    }

    function withdrawAll() public {
        uint256[] memory depositIds = allUserDepositIds[msg.sender].values();
        for (uint256 i = 0; i < depositIds.length; i++) {
            withdraw(type(uint256).max, depositIds[i]);
        }
    }

    function setRewardPools(address[] memory _rewardPools) external onlyOwner {
        rewardPools = _rewardPools;
    }

    function setOwner(address _owner) external onlyGov {
        owner = _owner;
        emit SetOwner(_owner);
    }

    function setGov(address _gov) external onlyGov {
        gov = _gov;
        emit SetGov(_gov);
    }

    /// @notice EMERGENCY ONLY
    function toggleUnlockAll() external onlyOwner updateRewards {
        unlockAll = unlockAll ? false : true;
    }

    function unlocked(address _account, uint256 _depositId) public view returns (uint256 amount) {
        UserInfo storage user = userInfo[_account][_depositId];
        Lock _lock = user.lock;

        if (block.timestamp >= user.lockedUntil || unlockAll) {
            amount = user.depositAmount;
        } else {
            amount = 0;
        }
    }

    function unlockedAll(address _account) external view returns (uint256 amount) {
        amount = 0;
        uint256 len = allUserDepositIds[_account].length();
        for (uint256 i = 0; i < len; i++) {
            uint256 depositId = allUserDepositIds[_account].at(i);
            amount += unlocked(_account, depositId);
        }
    }

    function deposited(address _account, uint256 _depositId) public view returns(uint256) {
        return userInfo[_account][_depositId].depositAmount;
    }

    function depositedAll(address _account) external view returns(uint256 depositedAllAmount) {
        depositedAllAmount = 0;
        uint256 len = allUserDepositIds[_account].length();
        for (uint256 i = 0; i < len; i++) {
            uint256 depositId = allUserDepositIds[_account].at(i);
            depositedAllAmount += deposited(_account, depositId);
        }
    }

    function _addDeposit(address _user) internal returns (UserInfo storage user, uint256 newDepositId) {
        // start depositId from 1
        newDepositId = ++currentId[_user];
        allUserDepositIds[_user].add(newDepositId);
        user = userInfo[_user][newDepositId];
    }

    function _removeDeposit(address _user, uint256 _depositId) internal {
        require(allUserDepositIds[_user].remove(_depositId), 'depositId !exists');
    }

    modifier updateRewards() {
        for (uint256 i = 0; i < rewardPools.length; i++) {
            IVaultReward(rewardPools[i]).updateReward(msg.sender);
        }
        _;
    }

    modifier onlyGov() {
        require(msg.sender == gov, "!gov");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }
}