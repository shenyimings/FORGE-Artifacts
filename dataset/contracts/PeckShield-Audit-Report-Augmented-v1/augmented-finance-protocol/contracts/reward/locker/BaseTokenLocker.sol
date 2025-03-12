// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {IERC20} from '../../dependencies/openzeppelin/contracts/IERC20.sol';

import {SafeERC20} from '../../dependencies/openzeppelin/contracts/SafeERC20.sol';
import {SafeMath} from '../../dependencies/openzeppelin/contracts/SafeMath.sol';
import {WadRayMath} from '../../tools/math/WadRayMath.sol';

import {AccessFlags} from '../../access/AccessFlags.sol';
import {MarketAccessBitmask} from '../../access/MarketAccessBitmask.sol';
import {IMarketAccessController} from '../../access/interfaces/IMarketAccessController.sol';
import {IEmergencyAccess} from '../../interfaces/IEmergencyAccess.sol';
import {IDerivedToken} from '../../interfaces/IDerivedToken.sol';

import {CalcLinearRateReward} from '../calcs/CalcLinearRateReward.sol';

import {Errors} from '../../tools/Errors.sol';

import 'hardhat/console.sol';

/**
  @dev Curve-like locker, that locks an underlying token for some period and mints non-transferrable tokens for that period. 
  Total amount of minted tokens = amount_of_locked_tokens * max_period / lock_period.
  End of lock period is aligned to week.

  Additionally, this contract recycles token excess of capped rewards by spreading the excess over some period. 
 */

abstract contract BaseTokenLocker is IERC20, IDerivedToken {
  using SafeMath for uint256;
  using WadRayMath for uint256;
  using SafeERC20 for IERC20;

  IERC20 private _underlyingToken;

  // Total amount of minted tokens. This number is increased in situ for new locks, and decreased at week edges, when locks expire.
  uint256 private _stakedTotal;
  // Current extra rate that distributes the recycled excess. This number is increased in situ for new excess added, and decreased at week edges.
  uint256 private _extraRate;
  // Accumulated _extraRate
  uint256 private _excessAccum;

  /**
    @dev A future point, contains deltas to be applied at the relevant time (period's edge):
    - stakeDelta is amount to be subtracted from _stakedTotal
    - rateDelta is amount to be subtracted from _extraRate
  */
  struct Point {
    uint128 stakeDelta;
    uint128 rateDelta;
  }
  // Future points, indexed by point number (week number).
  mapping(uint32 => Point) _pointTotal;

  // Absolute limit of future points - 255 periods (weeks).
  uint32 private constant _maxDurationPoints = 255;
  // Period (in seconds) which gives 100% of lock tokens, must be less than _maxDurationPoints. Default = 208 weeks; // 4 * 52
  uint32 private _maxValuePeriod;
  // Duration of a single period. All points are aligned to it. Default = 1 week.
  uint32 private _pointPeriod;
  // Next (nearest future) known point.
  uint32 private _nextKnownPoint;
  // Latest (farest future) known point.
  uint32 private _lastKnownPoint;
  // Timestamp when internalUpdate() was invoked.
  uint32 private _lastUpdateTS;
  // Re-entrance guard for some of internalUpdate() operations.
  bool private _updateEntered;

  /**
    @dev Details about user's lock
  */
  struct UserBalance {
    // Total amount of underlying token received from the user
    uint192 underlyingAmount;
    // Timestamp (not point) when the lock was created
    uint32 startTS;
    // Point number (week number), when the lock expired
    uint32 endPoint;
  }

  // Balances of users
  mapping(address => UserBalance) private _balances;
  // Addresses which are allowed to add to user's lock
  // map[user][delegate]
  mapping(address => mapping(address => bool)) private _allowAdd;

  event Locked(
    address from,
    address indexed to,
    uint256 underlyingAmountAdded,
    uint256 underlyingAmountTotal,
    uint256 amount,
    uint32 indexed expiry,
    uint256 indexed referral
  );
  event Redeemed(address indexed from, address indexed to, uint256 underlyingAmount);

  /// @param underlying ERC20 token to be locked
  /// @param pointPeriod duration in seconds of a single period
  /// @param maxValuePeriod duration in seconds of period with 100% lock ratio, must be less than 255*pointPeriod
  constructor(
    address underlying,
    uint32 pointPeriod,
    uint32 maxValuePeriod
  ) public {
    _initialize(underlying, pointPeriod, maxValuePeriod);
  }

  /// @dev To be used for initializers only. Same as constructor.
  function _initialize(
    address underlying,
    uint32 pointPeriod,
    uint32 maxValuePeriod
  ) internal {
    require(pointPeriod > 0, 'invalid pointPeriod');
    require(maxValuePeriod > pointPeriod, 'invalid maxValuePeriod');
    require(maxValuePeriod < pointPeriod * _maxDurationPoints, 'invalid maxValuePeriod');

    _underlyingToken = IERC20(underlying);
    _pointPeriod = pointPeriod;
    _maxValuePeriod = maxValuePeriod;
  }

  function UNDERLYING_ASSET_ADDRESS() external view override returns (address) {
    return address(_underlyingToken);
  }

  /** @dev Creates a new lock or adds more underlying to an existing lock of the caller:
      - with duration =0 this function adds to an existing unexpired lock without chaning lock's expiry, otherwise will fail (expired lock)
      - when a lock exists, the expiry (end) of the lock will be maximum of the current lock and of to-be-lock with the given duration.
      - when a lock has expired, but tokens were not redeemed these unredeemed tokens will also be added to the new locked.
      @param underlyingAmount amount of underlying (>0) to be added to the lock. Must be approved for transferFrom.
      @param duration in seconds of the lock. This duration will be rounded up to make sure that lock will end at a week's edge. 
      Zero value indicates addition to an existing lock without changing expiry.
      @param referral code to use for marketing campaings. Use 0 when not involved.      
      @return total amount of lock tokens of the user.
   */
  function lock(
    uint256 underlyingAmount,
    uint32 duration,
    uint256 referral
  ) external returns (uint256) {
    require(underlyingAmount > 0, 'ZERO_UNDERLYING');
    //    require(duration > 0, 'ZERO_DURATION');

    (uint256 stakeAmount, uint256 recoverableError) =
      internalLock(msg.sender, msg.sender, underlyingAmount, duration, referral, true);

    revertOnError(recoverableError);
    return stakeAmount;
  }

  /** @dev Extends an existing lock of the caller without adding more underlying. 
      @param duration in seconds (>0) of the lock. This duration will be rounded up to make sure that lock will end at a week's edge. 
      @return total amount of lock tokens of the user.
   */
  function lockExtend(uint32 duration) external returns (uint256) {
    require(duration > 0, 'ZERO_DURATION');

    (uint256 stakeAmount, uint256 recoverableError) =
      internalLock(msg.sender, msg.sender, 0, duration, 0, false);

    revertOnError(recoverableError);
    return stakeAmount;
  }

  /** @dev Allows/disallows another user/contract to use lockAdd() function for the caller's lock.
      @param to an address who will call lockAdd().
      @param allow indicates if calls are allowed (true) or disallowed (false).
   */
  function allowAdd(address to, bool allow) external {
    _allowAdd[msg.sender][to] = allow;
  }

  /** @dev A function to add funds to a lock of another user. Must be explicitly allowed with allowAdd().
      @param to an address to whose lock the given underlyingAmount shoud be added
      @param underlyingAmount amount of underlying (>0) to be added to the lock. Must be approved for transferFrom.
      @return total amount of lock tokens of the "to" address.
   */
  function lockAdd(address to, uint256 underlyingAmount) external returns (uint256) {
    require(underlyingAmount > 0, 'ZERO_UNDERLYING');
    require(_allowAdd[to][msg.sender], 'ADD_TO_LOCK_RESTRICTED');

    (uint256 stakeAmount, uint256 recoverableError) =
      internalLock(msg.sender, to, underlyingAmount, 0, 0, true);

    revertOnError(recoverableError);
    return stakeAmount;
  }

  // These constants are "soft" errors - such errors can be detected by the autolock function so it can stop automatically
  uint256 private constant LOCK_ERR_NOTHING_IS_LOCKED = 1;
  uint256 private constant LOCK_ERR_DURATION_IS_TOO_LARGE = 2;
  uint256 private constant LOCK_ERR_UNDERLYING_OVERFLOW = 3;
  uint256 private constant LOCK_ERR_LOCK_OVERFLOW = 4;

  /// @dev Converts "soft" errors into "hard" reverts
  function revertOnError(uint256 recoverableError) private pure {
    require(recoverableError != LOCK_ERR_LOCK_OVERFLOW, 'LOCK_ERR_LOCK_OVERFLOW');
    require(recoverableError != LOCK_ERR_UNDERLYING_OVERFLOW, 'LOCK_ERR_UNDERLYING_OVERFLOW');
    require(recoverableError != LOCK_ERR_DURATION_IS_TOO_LARGE, 'LOCK_ERR_DURATION_IS_TOO_LARGE');
    require(recoverableError != LOCK_ERR_NOTHING_IS_LOCKED, 'NOTHING_IS_LOCKED');
    require(recoverableError == 0, 'UNKNOWN_RECOVERABLE_ERROR');
  }

  /** @dev Creates a new lock or adds underlying to an existing lock or extends it.
      @param from whom the funds (underlying) will be taken
      @param to whom the funds will be locked
      @param underlyingTransfer amount of underlying (=>0) to be added to the lock.
      @param duration in seconds of the lock. This duration will be rounded up to make sure that lock will end at a week's edge. 
      Zero value indicates addition to an existing lock without changing expiry.
      @param transfer indicates when transferFrom should be called. E.g. autolock uses false, as tokens will be minted externally to this contract.
      @param referral code to use for marketing campaings. Use 0 when not involved.
      @return stakeAmount is total amount of lock tokens of the "to" address; recoverableError is the "soft" error code.
   */
  function internalLock(
    address from,
    address to,
    uint256 underlyingTransfer,
    uint32 duration,
    uint256 referral,
    bool transfer
  ) internal returns (uint256 stakeAmount, uint256 recoverableError) {
    require(from != address(0), 'ZERO_FROM');
    require(to != address(0), 'ZERO_TO');

    uint32 currentPoint = internalUpdate(true, 0);

    // this call ensures that time-based reward calculations are pulled up to this moment
    internalSyncRate(uint32(block.timestamp));

    UserBalance memory userBalance = _balances[to];

    uint256 prevStake;
    {
      // ======== ATTN! DO NOT APPLY STATE CHANGES STARTING FROM HERE ========
      {
        // ATTN! Should be no overflow checks here
        uint256 underlyingBalance = underlyingTransfer + userBalance.underlyingAmount;

        if (underlyingBalance < underlyingTransfer || underlyingBalance > type(uint192).max) {
          return (0, LOCK_ERR_UNDERLYING_OVERFLOW);
        } else if (underlyingBalance == 0) {
          return (0, LOCK_ERR_NOTHING_IS_LOCKED);
        }
        userBalance.underlyingAmount = uint192(underlyingBalance);
      }

      uint32 newEndPoint;
      if (duration < _pointPeriod) {
        // at least 1 full week is required
        newEndPoint = 1 + (uint32(block.timestamp + _pointPeriod - 1) / _pointPeriod);
      } else {
        newEndPoint = uint32(block.timestamp + duration + (_pointPeriod >> 1)) / _pointPeriod;
      }

      if (newEndPoint > currentPoint + _maxDurationPoints) {
        return (0, LOCK_ERR_DURATION_IS_TOO_LARGE);
      }

      if (userBalance.endPoint > currentPoint) {
        // lock is still valid - reuse it
        // so keep startTS and use the farest endTS
        require(userBalance.startTS > 0);

        prevStake = getStakeBalance(to);

        if (userBalance.endPoint > newEndPoint) {
          newEndPoint = userBalance.endPoint;
        }
      } else if (duration == 0) {
        // can't add to an expired lock
        return (0, LOCK_ERR_NOTHING_IS_LOCKED);
      } else {
        // new lock -> new start
        userBalance.startTS = uint32(block.timestamp);
      }

      {
        uint256 adjDuration = uint256(newEndPoint * _pointPeriod).sub(userBalance.startTS);
        if (adjDuration < _maxValuePeriod) {
          stakeAmount = uint256(userBalance.underlyingAmount).mul(adjDuration).div(_maxValuePeriod);
        } else {
          stakeAmount = userBalance.underlyingAmount;
        }
      }

      // ATTN! Should be no overflow checks here
      uint256 newStakeDelta = stakeAmount + _pointTotal[newEndPoint].stakeDelta;

      if (newStakeDelta < stakeAmount || newStakeDelta > type(uint128).max) {
        return (0, LOCK_ERR_LOCK_OVERFLOW);
      }

      // ======== ATTN! "DO NOT APPLY STATE CHANGES" ENDS HERE ========

      if (prevStake > 0) {
        if (userBalance.endPoint == newEndPoint) {
          newStakeDelta = newStakeDelta.sub(prevStake);
        } else {
          _pointTotal[userBalance.endPoint].stakeDelta = uint128(
            uint256(_pointTotal[userBalance.endPoint].stakeDelta).sub(prevStake)
          );
        }
        _stakedTotal = _stakedTotal.sub(prevStake);
      }

      if (userBalance.endPoint <= currentPoint) {
        // sum up rewards for the previous balance
        unsetStakeBalance(to, userBalance.endPoint * _pointPeriod, true);
        prevStake = 0;
      }

      userBalance.endPoint = newEndPoint;

      // range check is done above
      _pointTotal[newEndPoint].stakeDelta = uint128(newStakeDelta);
      _stakedTotal = _stakedTotal.add(stakeAmount);
    }

    if (_nextKnownPoint > userBalance.endPoint || _nextKnownPoint == 0) {
      _nextKnownPoint = userBalance.endPoint;
    }

    if (_lastKnownPoint < userBalance.endPoint || _lastKnownPoint == 0) {
      _lastKnownPoint = userBalance.endPoint;
    }

    if (prevStake != stakeAmount) {
      setStakeBalance(to, uint224(stakeAmount));
    }

    _balances[to] = userBalance;

    if (transfer) {
      _underlyingToken.safeTransferFrom(from, address(this), underlyingTransfer);
    }

    emit Locked(
      from,
      to,
      underlyingTransfer,
      userBalance.underlyingAmount,
      stakeAmount,
      userBalance.endPoint * _pointPeriod,
      referral
    );
    return (stakeAmount, 0);
  }

  /// @dev Returns amount of underlying for the given address
  function balanceOfUnderlying(address account) public view returns (uint256) {
    return _balances[account].underlyingAmount;
  }

  /// @dev Returns amount of underlying and a timestamp when the lock expires. Funds can be redeemed after the timestamp.
  function balanceOfUnderlyingAndExpiry(address account)
    external
    view
    returns (uint256 underlying, uint32 availableSince)
  {
    underlying = _balances[account].underlyingAmount;
    if (underlying == 0) {
      return (0, 0);
    }
    return (underlying, _balances[account].endPoint * _pointPeriod);
  }

  function expiryOf(address account)
    internal
    view
    returns (uint32 lockedSince, uint32 availableSince)
  {
    return (_balances[account].startTS, _balances[account].endPoint * _pointPeriod);
  }

  /**
   * @dev Attemps to redeem all underlying tokens of caller. Will not revert on zero or locked balance.
   * @param to address to which all redeemed tokens should be transferred.
   * @return underlyingAmount redeemed. Zero for an unexpired lock.
   **/
  function redeem(address to) public virtual returns (uint256 underlyingAmount) {
    return internalRedeem(msg.sender, to);
  }

  function internalRedeem(address from, address to) private returns (uint256 underlyingAmount) {
    uint32 currentPoint = internalUpdate(true, 0);
    UserBalance memory userBalance = _balances[from];

    if (userBalance.underlyingAmount == 0 || userBalance.endPoint > currentPoint) {
      // not yet
      return 0;
    }

    // pay off rewards and stop
    unsetStakeBalance(from, userBalance.endPoint * _pointPeriod, false);

    delete (_balances[from]);

    _underlyingToken.safeTransfer(to, userBalance.underlyingAmount);

    emit Redeemed(from, to, userBalance.underlyingAmount);
    return userBalance.underlyingAmount;
  }

  /// @dev Explicit call to applies all future-in-past points. Only useful to handle a situation when there were no state-changing calls for a long time.
  /// @param scanLimit defines a maximum number of points / updates to be processed at once.
  function update(uint256 scanLimit) public {
    internalUpdate(false, scanLimit);
  }

  function isCompletedPast(uint32 at) internal view returns (bool) {
    return at <= (_lastUpdateTS / _pointPeriod) * _pointPeriod;
  }

  function getScanRange(uint32 currentPoint, uint256 scanLimit)
    private
    view
    returns (
      uint32 fromPoint,
      uint32 tillPoint,
      uint32 maxPoint
    )
  {
    fromPoint = _nextKnownPoint;

    if (currentPoint < fromPoint || fromPoint == 0) {
      return (fromPoint, 0, 0);
    }

    maxPoint = _lastKnownPoint;
    if (maxPoint == 0) {
      // shouldn't happen, but as a precaution
      maxPoint = uint32(_lastUpdateTS / _pointPeriod) + _maxDurationPoints + 1;
    }

    if (scanLimit > 0 && scanLimit + fromPoint > scanLimit) {
      scanLimit += fromPoint;
      if (scanLimit < maxPoint) {
        maxPoint = uint32(scanLimit);
      }
    }

    if (maxPoint > currentPoint) {
      tillPoint = currentPoint;
    } else {
      tillPoint = maxPoint;
    }

    return (fromPoint, tillPoint, maxPoint);
  }

  /// @dev returns a total locked amount of underlying
  function totalOfUnderlying() external view returns (uint256) {
    return _underlyingToken.balanceOf(address(this));
  }

  function internalCurrentTotalSupply() internal view returns (uint256) {
    return _stakedTotal;
  }

  /// @dev returns a total amount of lock tokens
  function totalSupply() public view override returns (uint256 totalSupply_) {
    (uint32 fromPoint, uint32 tillPoint, ) =
      getScanRange(uint32(block.timestamp / _pointPeriod), 0);

    totalSupply_ = _stakedTotal;

    //    console.log('totalSupply', fromPoint, tillPoint, totalSupply_);

    if (tillPoint == 0) {
      return totalSupply_;
    }

    for (; fromPoint <= tillPoint; fromPoint++) {
      uint256 stakeDelta = _pointTotal[fromPoint].stakeDelta;
      if (stakeDelta == 0) {
        continue;
      }
      if (totalSupply_ == stakeDelta) {
        return 0;
      }
      totalSupply_ = totalSupply_.sub(stakeDelta);
    }

    return totalSupply_;
  }

  /// @param preventReentry when true will revert the call on re-entry, otherwise will exit immediately
  /// @param scanLimit limits number of updates to be applied. Must be zero (=unlimited) for all internal oprations, otherwise the state will be inconsisten.
  /// @return currentPoint (week number)
  function internalUpdate(bool preventReentry, uint256 scanLimit)
    internal
    returns (uint32 currentPoint)
  {
    currentPoint = uint32(block.timestamp / _pointPeriod);

    if (_updateEntered) {
      require(!preventReentry, 're-entry to stake or to redeem');
      return currentPoint;
    }
    if (_lastUpdateTS == uint32(block.timestamp)) {
      return currentPoint;
    }

    (uint32 fromPoint, uint32 tillPoint, uint32 maxPoint) = getScanRange(currentPoint, scanLimit);
    if (tillPoint > 0) {
      _updateEntered = true;
      {
        walkPoints(fromPoint, tillPoint, maxPoint);
      }
      _updateEntered = false;
    }

    _lastUpdateTS = uint32(block.timestamp);
    return currentPoint;
  }

  /// @dev searches and processes updates for future-in-past points and update next/last known points accordingly
  /// @param nextPoint start of future-in-past points (inclusive)
  /// @param tillPoint end of future-in-past points (inclusive)
  /// @param maxPoint the farest future point till which the next known point will be searched for
  function walkPoints(
    uint32 nextPoint,
    uint32 tillPoint,
    uint32 maxPoint
  ) private {
    Point memory delta = _pointTotal[nextPoint];

    for (; nextPoint <= tillPoint; ) {
      internalCheckpoint(nextPoint * _pointPeriod);

      _extraRate = _extraRate.sub(delta.rateDelta);
      _stakedTotal = _stakedTotal.sub(delta.stakeDelta);

      bool found = false;
      // look for the next non-zero point
      for (nextPoint++; nextPoint <= maxPoint; nextPoint++) {
        delta = _pointTotal[nextPoint];
        if (delta.stakeDelta > 0 || delta.rateDelta > 0) {
          found = true;
          break;
        }
      }
      if (found) {
        continue;
      }

      // keep nextPoint to reduce gas for further calls
      if (nextPoint > _lastKnownPoint) {
        nextPoint = 0;
      }
      break;
    }

    _nextKnownPoint = nextPoint;
    if (nextPoint == 0 || nextPoint > _lastKnownPoint) {
      _lastKnownPoint = nextPoint;
    }
  }

  function getUnderlying() internal view returns (address) {
    return address(_underlyingToken);
  }

  function transfer(address, uint256) external override returns (bool) {
    notSupported();
  }

  function allowance(address, address) external view override returns (uint256) {
    notSupported();
  }

  function approve(address, uint256) external override returns (bool) {
    notSupported();
  }

  function transferFrom(
    address,
    address,
    uint256
  ) external override returns (bool) {
    notSupported();
  }

  function notSupported() private pure {
    revert('NOT_SUPPORTED');
  }

  /// @dev internalAddExcess recycles reward excess by spreading the given amount.
  /// The given amount is distributed starting from now for the same period that has passed from (since) till now.
  /// @param amount of reward to be redistributed.
  /// @param since a timestamp (in the past) since which the given amount was accumulated.
  /// No restrictions on since value - zero, current or event future timestamps are handled.
  function internalAddExcess(uint256 amount, uint32 since) internal {
    uint32 at = uint32(block.timestamp);
    uint32 expiry;

    if (since == 0 || since >= at) {
      expiry = 1;
    } else {
      expiry = at - since;
      if (expiry > _maxValuePeriod) {
        expiry = _maxValuePeriod;
      }
    }

    uint32 expiryPt = 1 + uint32(expiry + at + _pointPeriod - 1) / _pointPeriod;
    expiry = expiryPt * _pointPeriod;

    // console.log('internalAddExcess', amount, since, _excessAccum);
    // console.log('internalAddExcess_1', expiry, expiryPt, expiry - at);

    expiry -= at;
    amount += _excessAccum;
    uint256 excessRateIncrement = amount / expiry;
    // if (excessRateIncrement < _extraRate>>10) {
    //   excessRateIncrement = 0;
    // }
    _excessAccum = amount - excessRateIncrement * expiry;

    // console.log(
    //   'internalAddExcess_2',
    //   excessRateIncrement,
    //   block.timestamp,
    //   _excessAccum
    // );

    if (excessRateIncrement == 0) {
      return;
    }

    internalSyncRate(at);

    // console.log(
    //   'internalAddExcess_3',
    //   _extraRate,
    //   _extraRate.add(excessRateIncrement)
    // );

    _extraRate = _extraRate.add(excessRateIncrement);

    excessRateIncrement = excessRateIncrement.add(_pointTotal[expiryPt].rateDelta);
    require(excessRateIncrement <= type(uint128).max);
    _pointTotal[expiryPt].rateDelta = uint128(excessRateIncrement);

    if (_nextKnownPoint > expiryPt || _nextKnownPoint == 0) {
      _nextKnownPoint = expiryPt;
    }

    if (_lastKnownPoint < expiryPt || _lastKnownPoint == 0) {
      _lastKnownPoint = expiryPt;
    }
  }

  /// @dev is called to syncronize reward accumulators
  /// @param at timestamp till which accumulators should be updated
  function internalSyncRate(uint32 at) internal virtual;

  /// @dev is called to update rate history
  /// @param at timestamp for which the current state should be records as a history point
  function internalCheckpoint(uint32 at) internal virtual;

  /// @dev is called to sum up reward and to stop issuing it
  /// @param holder of reward
  /// @param at timestamp till which reward should be calculated
  /// @param interim is true when setStakeBalance will be called right after this one
  function unsetStakeBalance(
    address holder,
    uint32 at,
    bool interim
  ) internal virtual;

  /// @dev is called to sum up reward upto now and start calculation of the reward for the new stakeAmount
  /// @param holder of reward
  /// @param stakeAmount of lock tokens for reward calculation
  function setStakeBalance(address holder, uint224 stakeAmount) internal virtual;

  function getStakeBalance(address holder) internal view virtual returns (uint224 stakeAmount);

  function convertLockedToUnderlying(uint256 lockedAmount, uint32 lockDuration)
    public
    view
    returns (uint256)
  {
    if (lockDuration > _maxValuePeriod) {
      lockDuration = _maxValuePeriod;
    }

    lockDuration = (lockDuration + (_pointPeriod >> 1)) / _pointPeriod;
    lockDuration *= _pointPeriod;

    if (lockDuration < _maxValuePeriod) {
      return lockedAmount.mul(_maxValuePeriod).div(lockDuration);
    }
    return lockedAmount;
  }

  function convertUnderlyingToLocked(uint256 underlyingAmount, uint32 lockDuration)
    public
    view
    returns (uint256 lockedAmount)
  {
    if (lockDuration > _maxValuePeriod) {
      lockDuration = _maxValuePeriod;
    }

    lockDuration = (lockDuration + (_pointPeriod >> 1)) / _pointPeriod;
    lockDuration *= _pointPeriod;

    if (lockDuration < _maxValuePeriod) {
      return underlyingAmount.mul(lockDuration).div(_maxValuePeriod);
    }
    return underlyingAmount;
  }

  /// @dev returns current rate of reward excess / redistribution.
  /// This function is used by decsendants.
  function getExtraRate() internal view returns (uint256) {
    return _extraRate;
  }

  /// @dev returns unadjusted (current state) amount of lock tokens.
  /// This function is used by decsendants.
  function getStakedTotal() internal view returns (uint256) {
    return _stakedTotal;
  }
}
