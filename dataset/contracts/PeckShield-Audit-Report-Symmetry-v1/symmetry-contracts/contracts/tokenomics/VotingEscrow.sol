// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../utils/Initializable.sol";
import "../utils/CommonContext.sol";

import "../interfaces/IVotingEscrow.sol";

import "./VotingEscrowCallback.sol";

contract VotingEscrow is IVotingEscrow, CommonContext, ReentrancyGuard, AccessControlEnumerable, Initializable {
    using SafeERC20 for IERC20;

    /*=== constants ===*/
    bytes32 public constant WHITELIST_ROLE = keccak256("WHITELIST_ROLE");
    bytes32 public constant VESTING_ROLE = keccak256("VESTING_ROLE");

    // reserved storage slots for base contract upgrade in future
    uint[50] private __gap;

    /*=== states === */
    address public baseToken;
    uint public maxTime;
    uint public vestWeeks;
    address public callbackRelayer;

    // erc20
    string public name;
    string public symbol;
    uint8 public decimals;

    // global states
    Point[] public pointHistory;
    mapping(uint => int128) public slopeChanges;
    // user locked states
    mapping(address => Point[]) private _userPointHistory;
    mapping(address => mapping(uint => int128)) public userSlopeChanges;
    mapping(address => LockedBalance) public locked;
    // user staked states
    mapping(address => StakedPoint[]) private _userStakedHistory;
    mapping(address => uint) public staked;
    // user vesting states
    mapping(address => Vest[]) private _userVestHistory;
    mapping(address => uint) public userClaimEpoch;

    function initialize(
        address _baseToken,
        uint _maxTime,
        uint _vestWeeks,
        string memory _name,
        string memory _symbol
    ) external onlyInitializeOnce {
        baseToken = _baseToken;
        maxTime = _maxTime;
        vestWeeks = _vestWeeks;

        Point memory init = Point({bias: int128(0), slope: int128(0), ts: block.timestamp});
        pointHistory.push(init);

        decimals = IERC20Metadata(_baseToken).decimals();
        require(decimals <= 18, "VotingEscrow: Cannot have more than 18 decimals");

        name = _name;
        symbol = _symbol;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /*=== owner ===*/

    function setCallbackRelayer(address _relayer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        callbackRelayer = _relayer;
    }

    /*=== getter ===*/

    function globalEpoch() public view returns (uint) {
        // pointHistory length is >= 1, ensured by initialize()
        return pointHistory.length - 1;
    }

    function userPointEpoch(address _addr) public view returns (uint) {
        uint epoch = _userPointHistory[_addr].length;
        return epoch > 0 ? epoch - 1 : 0;
    }

    function userStakedEpoch(address _addr) public view returns (uint) {
        uint epoch = _userStakedHistory[_addr].length;
        return epoch > 0 ? epoch - 1 : 0;
    }

    function userVestEpoch(address _addr) public view returns (uint) {
        uint epoch = _userVestHistory[_addr].length;
        return epoch > 0 ? epoch - 1 : 0;
    }

    function userPointHistory(address _addr, uint _idx) external view returns (Point memory) {
        return _userPointHistory[_addr][_idx];
    }

    function userStakedHistory(address _addr, uint _idx) external view returns (StakedPoint memory) {
        return _userStakedHistory[_addr][_idx];
    }

    function userVestHistory(address _addr, uint _idx) external view returns (Vest memory) {
        return _userVestHistory[_addr][_idx];
    }

    function userVestAt(address _addr, uint _ts) external view returns (Vest memory) {
        uint epoch = findUserVested(_addr, _ts);
        return epoch == 0 ? Vest({amount: 0, ts: 0}) : _userVestHistory[_addr][epoch];
    }

    function getLastStakedPoint(address _addr) public view returns (StakedPoint memory point) {
        point = StakedPoint({bias: 0, slope: 0, ts: 0, end: 0});
        uint epoch = userStakedEpoch(_addr);
        if (epoch == 0) {
            return point;
        }
        point = _userStakedHistory[_addr][epoch];
        point.bias = SafeCast.toInt128(SafeCast.toInt256(stakedBalance(point, block.timestamp)));
        point.ts = block.timestamp;
    }

    function getVested(address _addr) external view returns (uint) {
        uint vestedEpoch = userVestEpoch(_addr);
        uint claimEpoch = userClaimEpoch[_addr];
        if (claimEpoch == 0) {
            claimEpoch = 1;
        }
        uint vested = 0;
        for (uint i = claimEpoch; i <= vestedEpoch; ++i) {
            vested += _userVestHistory[_addr][i].amount;
        }

        return vested;
    }

    /*===  helper functions ===*/

    /* solhint-disable avoid-tx-origin */
    function _assertNotContract() private view {
        if (msg.sender != tx.origin) {
            require(hasRole(WHITELIST_ROLE, msg.sender), "VotingEscrow: Smart contract depositors not allowed");
        }
    }

    /* solhint-enable avoid-tx-origin */

    function _tryCallback(address _addr) internal {
        if (callbackRelayer != address(0)) {
            VotingEscrowCallback(callbackRelayer).syncWithVotingEscrow(_addr);
        }
    }

    /*=== Voting Escrow ===*/
    function _checkpoint() internal returns (Point memory lastPoint) {
        lastPoint = Point({bias: 0, slope: 0, ts: block.timestamp});
        uint epoch = globalEpoch();
        if (epoch > 0) {
            lastPoint = pointHistory[epoch];
        }
        // Go over weeks to fill history and calculate what the current point is
        uint iterativeTime = _startOfWeek(lastPoint.ts);
        for (uint i = 0; i < 255; i++) {
            // Hopefully it won't happen that this won't get used in 5 years!
            // If it does, users will be able to withdraw but vote weight will be broken
            iterativeTime += 1 weeks;
            int128 dSlope = 0;
            if (iterativeTime > block.timestamp) {
                iterativeTime = block.timestamp;
            } else {
                dSlope = slopeChanges[iterativeTime];
            }
            int128 biasDelta = lastPoint.slope * SafeCast.toInt128(int(iterativeTime - lastPoint.ts));
            lastPoint.bias -= biasDelta;
            lastPoint.slope += dSlope;
            // This can happen
            if (lastPoint.bias < 0) {
                lastPoint.bias = 0;
            }
            lastPoint.ts = iterativeTime;

            if (iterativeTime == block.timestamp) {
                break;
            } else {
                pointHistory.push(lastPoint);
            }
        }
    }

    /**
     * @dev Record global data to checkpoint
     */
    function checkpoint() external {
        _checkpoint();
    }

    /**
     * @dev Uses binarysearch to find the most recent point history whose timestamp <= given timestamp
     * @param _timestamp Find the most recent point history before this timestamp
     */
    function findPoint(uint _timestamp) public view returns (uint) {
        // Binary search
        uint min = 0;
        uint max = globalEpoch();
        while (min < max) {
            uint mid = (min + max + 1) / 2;
            if (pointHistory[mid].ts <= _timestamp) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return min;
    }

    /**
     * @dev Calculate point at a timestamp in the past
     * @param _point Most recent point before time _t
     * @param _t Time at which to calculate supply
     * @return point at given time
     */
    function _pointAt(Point memory _point, uint _t) internal view returns (Point memory) {
        Point memory lastPoint = _point;
        // Floor the timestamp to weekly interval
        uint iterativeTime = _startOfWeek(lastPoint.ts);
        // Iterate through all weeks between _point & _t to account for slope changes
        for (uint i = 0; i < 255; i++) {
            iterativeTime += 1 weeks;
            int128 dSlope = 0;
            if (iterativeTime > _t) {
                iterativeTime = _t;
            } else {
                dSlope = slopeChanges[iterativeTime];
            }

            lastPoint.bias -= lastPoint.slope * SafeCast.toInt128(int(iterativeTime - lastPoint.ts));
            lastPoint.slope += dSlope;
            lastPoint.ts = iterativeTime;
            if (iterativeTime == _t) {
                break;
            }
        }

        if (lastPoint.bias < 0) {
            lastPoint.bias = 0;
        }
        return lastPoint;
    }

    /**
     * @dev Calculate total voting power
     * @return Total total voting power
     */
    function totalSupply() public view returns (uint) {
        uint epoch_ = globalEpoch();
        Point memory lastPoint = pointHistory[epoch_];
        return SafeCast.toUint256(_pointAt(lastPoint, block.timestamp).bias);
    }

    function pointAt(uint _timestamp) public view returns (Point memory) {
        uint targetEpoch = findPoint(_timestamp);
        if (targetEpoch == 0) {
            return Point({bias: 0, slope: 0, ts: _timestamp});
        }

        Point memory point = pointHistory[targetEpoch];
        return _pointAt(point, _timestamp);
    }

    /**
     * @dev Calculate total voting power at a timestamp in the past
     * @param _timestamp Time at which to calculate supply
     * @return Total voting power at `_timestamp`
     */
    function totalSupplyAt(uint _timestamp) public view returns (uint) {
        return SafeCast.toUint256(pointAt(_timestamp).bias);
    }

    function balanceOf(address _addr) public view returns (uint) {
        return lockedBalanceOf(_addr) + stakedBalanceOf(_addr);
    }

    function balanceOfAt(address _addr, uint _timestamp) public view returns (uint) {
        return lockedBalanceOfAt(_addr, _timestamp) + stakedBalanceOfAt(_addr, _timestamp);
    }

    /*=== vesting ===*/
    function findUserVested(address _addr, uint _timestamp) public view returns (uint) {
        uint min = 0;
        uint max = userVestEpoch(_addr);
        while (min < max) {
            uint mid = (min + max + 1) / 2;
            if (_userVestHistory[_addr][mid].ts <= _timestamp) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return min;
    }

    function vest(address _addr, uint _amount) external onlyRole(VESTING_ROLE) {
        require(_amount > 0, "VotingEscrow: need non-zero value");

        uint uepoch = userVestEpoch(_addr);
        if (uepoch == 0) {
            _userVestHistory[_addr].push(Vest({amount: 0, ts: 0}));
        }

        uint vestTs = _startOfWeek(block.timestamp);
        if (vestTs != block.timestamp) {
            // current timestamp is not start of a week
            // the first vest unlock time will be at start of the week after the next
            vestTs += 1 weeks;
        }
        uint epoch = findUserVested(_addr, vestTs + 1 weeks);
        uint len = vestWeeks;
        uint vestAmount = _amount / len;
        if (vestAmount == 0) {
            return;
        }
        LockedBalance[] memory oldLocks = new LockedBalance[](len);
        LockedBalance[] memory newLocks = new LockedBalance[](len);
        for (uint i = 0; i < len; ++i) {
            vestTs += 1 weeks;
            LockedBalance memory oldLocked = LockedBalance({
                amount: 0,
                end: vestTs,
                lockDuration: 0,
                autoExtend: false
            });
            LockedBalance memory newLocked = LockedBalance({
                amount: 0,
                end: vestTs,
                lockDuration: 0,
                autoExtend: false
            });
            if (epoch > uepoch || _userVestHistory[_addr][epoch].ts < vestTs) {
                _userVestHistory[_addr].push(Vest({amount: vestAmount, ts: vestTs}));
                newLocked.amount = vestAmount;
            } else {
                oldLocked.amount = _userVestHistory[_addr][epoch].amount;
                newLocked.amount = oldLocked.amount + vestAmount;
                _userVestHistory[_addr][epoch].amount = newLocked.amount;
            }
            ++epoch;
            oldLocks[i] = oldLocked;
            newLocks[i] = newLocked;
        }

        _checkpointLocked(_addr, oldLocks, newLocks);

        // callback here is unnecessary and may lead to reentrancy
        emit Vested(_addr, _amount, block.timestamp);
    }

    function claimVested(address _account) external returns (uint) {
        return _claimVested(_account);
    }

    function _claimVested(address _addr) internal returns (uint) {
        uint claimEpoch = userClaimEpoch[_addr];
        uint end = userVestEpoch(_addr);
        if (end > claimEpoch + 255) {
            end = claimEpoch + 255;
        }

        if (claimEpoch == 0) {
            claimEpoch = 1;
        }
        uint toClaim = 0;

        // at most $vestWeeks$ iterations
        while (claimEpoch <= end) {
            if (_userVestHistory[_addr][claimEpoch].ts > block.timestamp) {
                break;
            }
            toClaim += _userVestHistory[_addr][claimEpoch].amount;
            ++claimEpoch;
        }
        if (toClaim > 0) {
            userClaimEpoch[_addr] = claimEpoch;
            IERC20(baseToken).safeTransfer(_addr, toClaim);

            emit Claimed(_addr, toClaim, block.timestamp);
        }
        return toClaim;
    }

    /*=== stake ===*/
    function _checkpointStaked(address _addr, StakedPoint memory _oldStaked, StakedPoint memory _newStaked) internal {
        int128 oldSlope = block.timestamp >= _oldStaked.end ? int128(0) : _oldStaked.slope;
        int128 newSlope = block.timestamp >= _newStaked.end ? int128(0) : _newStaked.slope;

        _updateSlopeChanges(slopeChanges, _oldStaked.end, oldSlope, _newStaked.end, newSlope);

        Point memory lastPoint = _checkpoint();

        lastPoint.slope += newSlope - oldSlope;
        lastPoint.bias += _newStaked.bias - _oldStaked.bias;
        if (lastPoint.bias < 0) {
            lastPoint.bias = 0;
        }

        pointHistory.push(lastPoint);

        uint uEpoch = userStakedEpoch(_addr);
        if (uEpoch == 0) {
            _userStakedHistory[_addr].push(StakedPoint({bias: 0, slope: 0, ts: 0, end: 0}));
        }
        _userStakedHistory[_addr].push(_newStaked);
    }

    function findUserStaked(address _addr, uint _timestamp) public view returns (uint) {
        uint min = 0;
        uint max = userStakedEpoch(_addr);
        while (min < max) {
            uint mid = (min + max + 1) / 2;
            if (_userStakedHistory[_addr][mid].ts <= _timestamp) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return min;
    }

    function stakedBalance(StakedPoint memory _point, uint _ts) public pure returns (uint) {
        // since end time is rounded down to week, so this is possible
        if (_point.ts >= _point.end) {
            return SafeCast.toUint256(_point.bias);
        }
        int interval = SafeCast.toInt128(int((_ts > _point.end ? _point.end : _ts) - _point.ts));
        // slope is non-positive, bias >= 0
        return SafeCast.toUint256(_point.bias - (_point.slope * interval));
    }

    function stakedBalanceOf(address _addr) public view returns (uint) {
        uint epoch = userStakedEpoch(_addr);
        if (epoch == 0) {
            return 0;
        }
        StakedPoint memory lastPoint = _userStakedHistory[_addr][epoch];
        return stakedBalance(lastPoint, block.timestamp);
    }

    function stakedBalanceOfAt(address _addr, uint _timestamp) public view returns (uint) {
        // Get most recent user staked point
        uint userEpoch = findUserStaked(_addr, _timestamp);
        if (userEpoch == 0) {
            return 0;
        }
        StakedPoint memory upoint = _userStakedHistory[_addr][userEpoch];
        return stakedBalance(upoint, _timestamp);
    }

    function stake(uint _value) external nonReentrant {
        _assertNotContract();

        require(_value > 0, "VotingEscrow: need non-zero value");
        IERC20(baseToken).safeTransferFrom(msg.sender, address(this), _value);
        uint stakedValue = staked[msg.sender] + _value;
        staked[msg.sender] = stakedValue;

        StakedPoint memory oldStaked = getLastStakedPoint(msg.sender);
        StakedPoint memory newStaked = StakedPoint({
            bias: oldStaked.bias,
            slope: -SafeCast.toInt128(SafeCast.toInt256(stakedValue / maxTime)),
            ts: block.timestamp,
            end: _startOfWeek(
                block.timestamp + ((stakedValue - SafeCast.toUint256(oldStaked.bias)) * maxTime) / stakedValue
            )
        });
        _checkpointStaked(msg.sender, oldStaked, newStaked);

        _tryCallback(msg.sender);
        emit Stake(msg.sender, _value, block.timestamp);
    }

    function unstake(uint _value) external nonReentrant {
        _assertNotContract();

        uint stakedValue = staked[msg.sender];
        require(stakedValue >= _value, "VotingEscrow: insufficient staked");
        stakedValue -= _value;
        staked[msg.sender] = stakedValue;

        StakedPoint memory oldStaked = getLastStakedPoint(msg.sender);
        StakedPoint memory newStaked = StakedPoint({
            bias: 0,
            slope: -SafeCast.toInt128(SafeCast.toInt256(stakedValue / maxTime)),
            ts: block.timestamp,
            end: _startOfWeek(block.timestamp + maxTime)
        });
        _checkpointStaked(msg.sender, oldStaked, newStaked);

        IERC20(baseToken).safeTransfer(msg.sender, _value);

        _tryCallback(msg.sender);
        emit Unstake(msg.sender, _value, block.timestamp);
    }

    /*=== lock ===*/
    function _userLockedPoint(
        address _addr,
        Point memory _point,
        uint _t
    ) internal view returns (Point memory lastPoint) {
        // _point is the latest point user made operation on veSYM before _t.
        // Hence, there can be at most $vestWeeks$ + 1 slope changes between this point and _t,
        // and these slope changes must happen in consecutive weeks following _point.
        // Therefore, we only need to iterate $vestWeeks$ + 1 weeks here.
        lastPoint = _point;
        uint iterativeTime = _startOfWeek(lastPoint.ts);
        uint len = vestWeeks + 1;
        for (uint i = 0; i < len; ++i) {
            iterativeTime += 1 weeks;
            int128 dSlope = 0;
            if (iterativeTime > _t) {
                iterativeTime = _t;
            } else {
                dSlope = userSlopeChanges[_addr][iterativeTime];
            }

            lastPoint.bias -= lastPoint.slope * SafeCast.toInt128(int(iterativeTime - lastPoint.ts));
            lastPoint.slope += dSlope;
            lastPoint.ts = iterativeTime;
            if (iterativeTime == _t) {
                break;
            }
        }
        // in the rest time period, there is at most one active lock by user
        lastPoint.bias -= lastPoint.slope * SafeCast.toInt128(int(_t - lastPoint.ts));
        if (lastPoint.bias < 0) {
            lastPoint.bias = 0;
            lastPoint.slope = 0;
        }
        lastPoint.ts = _t;
    }

    function _userCheckpoint(address _addr) internal view returns (Point memory lastPoint) {
        lastPoint = Point({bias: 0, slope: 0, ts: block.timestamp});
        uint epoch = userPointEpoch(_addr);
        if (epoch > 0) {
            lastPoint = _userPointHistory[_addr][epoch];
        }
        return _userLockedPoint(_addr, lastPoint, block.timestamp);
    }

    function _updateSlopeChanges(
        mapping(uint => int128) storage _changes,
        uint _oldEnd,
        int128 _oldSlope,
        uint _newEnd,
        int128 _newSlope
    ) internal {
        if (_oldEnd > block.timestamp) {
            int128 oldSlopeDelta = _changes[_oldEnd];
            oldSlopeDelta += _oldSlope;
            if (_newEnd == _oldEnd) {
                oldSlopeDelta -= _newSlope;
            }
            _changes[_oldEnd] = oldSlopeDelta;
        }
        if (_newEnd > block.timestamp) {
            if (_newEnd != _oldEnd) {
                _changes[_newEnd] -= _newSlope;
            }
        }
    }

    function _getLockedPoint(LockedBalance memory _locked) internal view returns (int128 bias, int128 slope) {
        if (_locked.autoExtend) {
            // point.slope = 0;
            bias = SafeCast.toInt128(SafeCast.toInt256((_locked.amount / maxTime) * _locked.lockDuration));
        } else {
            if (_locked.end > block.timestamp && _locked.amount > 0) {
                slope = SafeCast.toInt128(int(_locked.amount / maxTime));
                bias = slope * SafeCast.toInt128(int(_locked.end - block.timestamp));
            }
        }
    }

    /**
     * @dev Record global and per-user data to checkpoint on a new lock operation
     * @param _addr User's wallet address. No user checkpoint if 0x0
     * @param _oldLocked Pevious locked amount / end lock time for the user
     * @param _newLocked New locked amount / end lock time for the user
     */
    function _checkpointLocked(
        address _addr,
        LockedBalance[] memory _oldLocked,
        LockedBalance[] memory _newLocked
    ) internal {
        int128 userOldBias;
        int128 userOldSlope;
        int128 userNewSlope;
        int128 userNewBias;
        uint len = _oldLocked.length;
        for (uint i = 0; i < len; ++i) {
            (int128 oldBias, int128 oldSlope) = _getLockedPoint(_oldLocked[i]);
            (int128 newBias, int128 newSlope) = _getLockedPoint(_newLocked[i]);

            _updateSlopeChanges(slopeChanges, _oldLocked[i].end, oldSlope, _newLocked[i].end, newSlope);
            _updateSlopeChanges(userSlopeChanges[_addr], _oldLocked[i].end, oldSlope, _newLocked[i].end, newSlope);

            userOldSlope += oldSlope;
            userOldBias += oldBias;
            userNewSlope += newSlope;
            userNewBias += newBias;
        }

        Point memory lastPoint = _checkpoint();
        // Now pointHistory is filled until t=now

        // If last point was in this block, the slope change has been applied already
        lastPoint.slope += userNewSlope - userOldSlope;
        lastPoint.bias += userNewBias - userOldBias;
        if (lastPoint.bias < 0) {
            lastPoint.bias = 0;
        }

        // Record the changed point into history
        // pointHistory[epoch] = lastPoint;
        pointHistory.push(lastPoint);

        uint uEpoch = userPointEpoch(_addr);
        if (uEpoch == 0) {
            _userPointHistory[_addr].push(Point({bias: 0, slope: 0, ts: 0}));
        }
        // compute current user point
        Point memory userPoint = _userCheckpoint(_addr);
        userPoint.slope += userNewSlope - userOldSlope;
        userPoint.bias += userNewBias - userOldBias;
        _userPointHistory[_addr].push(userPoint);
    }

    /**
     * @dev Deposit and lock tokens for a user
     * @param _addr User's wallet address
     * @param _oldLocked Previous locked information
     * @param _newLocked New locked information
     * @param _action LockAction type
     */
    function _depositFor(
        address _addr,
        LockedBalance memory _oldLocked,
        LockedBalance memory _newLocked,
        LockAction _action
    ) internal {
        locked[_addr] = _newLocked;

        // Possibilities:
        // Both _oldLocked.end could be current or expired (>/< block.timestamp)
        // value == 0 (extend lock) or value > 0 (add to lock or extend lock)
        // newLocked.end > block.timestamp (always)
        LockedBalance[] memory oldLocks = new LockedBalance[](1);
        LockedBalance[] memory newLocks = new LockedBalance[](1);
        oldLocks[0] = _oldLocked;
        newLocks[0] = _newLocked;
        _checkpointLocked(_addr, oldLocks, newLocks);

        uint value = _newLocked.amount - _oldLocked.amount;
        if (value != 0) {
            IERC20(baseToken).safeTransferFrom(_addr, address(this), value);
        }
        emit Deposit(
            _addr,
            value,
            _newLocked.end,
            _newLocked.lockDuration,
            _newLocked.autoExtend,
            _action,
            block.timestamp
        );
    }

    /**
     * @dev Deposit `_value` tokens for `msg.sender` and lock until `_unlockTime`,
     *      or lock for `_lockDuration` if autoExtend is true
     * @param _value Amount to deposit
     * @param _unlockTime Time when tokens unlock
     * @param _lockDuration Time length of tokens to lock
     * @param _autoExtend If the lock will be auto extended
     */
    function createLock(uint _value, uint _unlockTime, uint _lockDuration, bool _autoExtend) external nonReentrant {
        _assertNotContract();

        _unlockTime = _startOfWeek(_unlockTime); // Locktime is rounded down to weeks
        LockedBalance memory oldLocked = locked[msg.sender];
        LockedBalance memory newLocked = LockedBalance({
            amount: _value,
            end: _autoExtend ? 0 : _unlockTime,
            lockDuration: _autoExtend ? _lockDuration : 0,
            autoExtend: _autoExtend
        });

        require(_value > 0, "VotingEscrow: need non-zero value");
        require(oldLocked.amount == 0, "VotingEscrow: Withdraw old tokens first");

        if (_autoExtend) {
            require(_lockDuration > 0 && _lockDuration <= maxTime, "VotingEscrow: invalid lock duration");
        } else {
            require(_unlockTime > block.timestamp, "VotingEscrow: Can only lock until time in the future");
            require(_unlockTime <= block.timestamp + maxTime, "VotingEscrow: Voting lock exceeds max time");
        }

        _depositFor(msg.sender, oldLocked, newLocked, LockAction.CREATE_LOCK);

        _tryCallback(msg.sender);
    }

    /**
     * @dev Deposit `_value` additional tokens for `msg.sender` without modifying the unlock time
     * @param _value Amount of tokens to deposit and add to the lock
     */
    function increaseLockAmount(uint _value) external nonReentrant {
        _increaseLockAmount(_value);

        _tryCallback(msg.sender);
    }

    /**
     * @dev Extend the unlock time for `msg.sender` to `_unlockTime`, or make the lock
     *      auto extended and set a longer lock duartion
     * @param _unlockTime New epoch time for unlocking
     * @param _lockDuration Time length of tokens to lock
     * @param _autoExtend If the lock will be auto extended
     */
    function increaseUnlockTime(uint _unlockTime, uint _lockDuration, bool _autoExtend) external nonReentrant {
        _increaseUnlockTime(_unlockTime, _lockDuration, _autoExtend);

        _tryCallback(msg.sender);
    }

    function increaseLockAmountAndUnlockTime(
        uint _value,
        uint _unlockTime,
        uint _lockDuration,
        bool _autoExtend
    ) external nonReentrant {
        _increaseLockAmount(_value);
        _increaseUnlockTime(_unlockTime, _lockDuration, _autoExtend);

        _tryCallback(msg.sender);
    }

    function _increaseLockAmount(uint _value) internal {
        _assertNotContract();

        LockedBalance memory oldLocked = locked[msg.sender];
        LockedBalance memory newLocked = LockedBalance({
            amount: oldLocked.amount + _value,
            end: oldLocked.end,
            lockDuration: oldLocked.lockDuration,
            autoExtend: oldLocked.autoExtend
        });

        require(_value > 0, "VotingEscrow: need non-zero value");
        require(oldLocked.amount > 0, "VotingEscrow: No existing lock found");
        if (!oldLocked.autoExtend) {
            require(oldLocked.end > block.timestamp, "VotingEscrow: Cannot add to expired lock. Withdraw");
        }

        _depositFor(msg.sender, oldLocked, newLocked, LockAction.INCREASE_LOCK_AMOUNT);
    }

    function _increaseUnlockTime(uint _unlockTime, uint _lockDuration, bool _autoExtend) internal {
        _assertNotContract();

        _unlockTime = _startOfWeek(_unlockTime); // Locktime is rounded down to weeks
        LockedBalance memory oldLocked = locked[msg.sender];
        LockedBalance memory newLocked = LockedBalance({
            amount: oldLocked.amount,
            end: _autoExtend ? 0 : _unlockTime,
            lockDuration: _autoExtend ? _lockDuration : 0,
            autoExtend: _autoExtend
        });

        if (!oldLocked.autoExtend) {
            require(oldLocked.end > block.timestamp, "VotingEscrow: Lock expired");
            if (
                (!newLocked.autoExtend && newLocked.end <= oldLocked.end) ||
                (newLocked.autoExtend && newLocked.lockDuration + block.timestamp < oldLocked.end)
            ) {
                revert("VotingEscrow: Can only increase unlock time");
            }
        } else if (
            // equation is allowed here to enable user to disable auto-extend
            (!newLocked.autoExtend && newLocked.end < oldLocked.lockDuration + block.timestamp) ||
            (newLocked.autoExtend && newLocked.lockDuration <= oldLocked.lockDuration)
        ) {
            revert("VotingEscrow: Can only increase unlock time");
        }
        require(oldLocked.amount > 0, "VotingEscrow: Nothing is locked");
        require(
            (!newLocked.autoExtend && newLocked.end <= block.timestamp + maxTime) ||
                (newLocked.autoExtend && newLocked.lockDuration <= maxTime),
            "VotingEscrow: Voting lock exceeds max time"
        );

        _depositFor(msg.sender, oldLocked, newLocked, LockAction.INCREASE_LOCK_TIME);
    }

    /**
     * @dev Withdraw all tokens for `msg.sender`, only possible if the lock has expired
     */
    function withdraw() external {
        _withdraw(msg.sender);
    }

    function _withdraw(address _addr) internal nonReentrant {
        LockedBalance memory oldLock = locked[_addr];
        require(!oldLock.autoExtend, "VotingEscrow: lock is auto extended");
        require(block.timestamp >= oldLock.end, "VotingEscrow: The lock didn't expire");

        delete locked[_addr];

        // checkpoint is not necessary here

        IERC20(baseToken).safeTransfer(_addr, oldLock.amount);

        emit Withdraw(_addr, oldLock.amount, block.timestamp);
    }

    /**
     * @dev Uses binarysearch to find the most recent point history whose timestamp <= given timestamp
     * @param _addr user address
     * @param _timestamp Find the most recent point history before this timestamp
     */
    function findUserPoint(address _addr, uint _timestamp) public view returns (uint) {
        uint min = 0;
        uint max = userPointEpoch(_addr);
        while (min < max) {
            uint mid = (min + max + 1) / 2;
            if (_userPointHistory[_addr][mid].ts <= _timestamp) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return min;
    }

    /**
     * @dev Get the current voting power for `msg.sender`
     * @param _addr User wallet address
     * @return uint voting power of user
     */
    function lockedBalanceOf(address _addr) public view returns (uint) {
        uint epoch = userPointEpoch(_addr);
        if (epoch == 0) {
            return 0;
        }
        Point memory lastPoint = _userPointHistory[_addr][epoch];
        return SafeCast.toUint256(_userLockedPoint(_addr, lastPoint, block.timestamp).bias);
    }

    /**
     * @dev Get the locked point for `msg.sender` at specific time
     * @param _addr User wallet address
     * @param _timestamp Time to query
     * @return Point user locked point
     */
    function lockedPointOfAt(address _addr, uint _timestamp) public view returns (Point memory) {
        // Get most recent user Point
        uint userEpoch = findUserPoint(_addr, _timestamp);
        if (userEpoch == 0) {
            return Point({bias: 0, slope: 0, ts: _timestamp});
        }
        Point memory upoint = _userPointHistory[_addr][userEpoch];
        return _userLockedPoint(_addr, upoint, _timestamp);
    }

    /**
     * @dev Get the voting power for `msg.sender` at specific time
     * @param _addr User wallet address
     * @param _timestamp Time to query
     * @return uint voting power of user
     */
    function lockedBalanceOfAt(address _addr, uint _timestamp) public view returns (uint) {
        return SafeCast.toUint256(lockedPointOfAt(_addr, _timestamp).bias);
    }
}
