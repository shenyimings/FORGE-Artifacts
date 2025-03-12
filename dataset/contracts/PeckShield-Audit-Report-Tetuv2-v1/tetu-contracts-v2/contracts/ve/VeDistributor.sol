// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../interfaces/IERC20.sol";
import "../interfaces/IVeTetu.sol";
import "../interfaces/IVeDistributor.sol";
import "../openzeppelin/SafeERC20.sol";
import "../openzeppelin/Math.sol";
import "../proxy/ControllableV3.sol";

/// @title Contract for distributing rewards to ve holders.
///        Rewards will be staked to the veNFT without extending lock period.
///        Based on Solidly contract.
/// @author belbix
contract VeDistributor is ControllableV3, IVeDistributor {
  using SafeERC20 for IERC20;

  // for contract internal purposes, don't need to store in the interface
  struct ClaimCalculationResult {
    uint toDistribute;
    uint userEpoch;
    uint weekCursor;
    uint maxUserEpoch;
    bool success;
  }

  // *************************************************************
  //                        CONSTANTS
  // *************************************************************

  /// @dev Version of this contract. Adjust manually on each code modification.
  string public constant VE_DIST_VERSION = "1.0.0";
  uint internal constant WEEK = 7 * 86400;

  // *************************************************************
  //                        VARIABLES
  //                Keep names and ordering!
  //                 Add only in the bottom.
  // *************************************************************

  /// @dev Voting escrow token address
  IVeTetu public ve;
  /// @dev Token for ve rewards
  address public override rewardToken;

  // --- CHECKPOINT

  /// @dev Cursor for the current epoch
  uint public activePeriod;
  /// @dev Tokens per week stored on checkpoint call. Predefined array size = max weeks size
  uint[1000000000000000] public tokensPerWeek;
  /// @dev Ve supply checkpoints. Predefined array size = max weeks size
  uint[1000000000000000] public veSupply;
  /// @dev Ve supply checkpoint time cursor
  uint public timeCursor;
  /// @dev Token balance updated on checkpoint/claim
  uint public tokenLastBalance;
  /// @dev Last checkpoint time
  uint public lastTokenTime;

  // --- CLAIM

  /// @dev Timestamp when this contract was inited
  uint public startTime;
  /// @dev veID => week cursor stored on the claim action
  mapping(uint => uint) public timeCursorOf;
  /// @dev veID => epoch stored on the claim action
  mapping(uint => uint) public userEpochOf;

  // *************************************************************
  //                        EVENTS
  // *************************************************************

  event CheckpointToken(
    uint time,
    uint tokens
  );

  event Claimed(
    uint tokenId,
    uint amount,
    uint claimEpoch,
    uint maxEpoch
  );

  // *************************************************************
  //                        INIT
  // *************************************************************

  /// @dev Proxy initialization. Call it after contract deploy.
  function init(
    address controller_,
    address _ve,
    address _rewardToken
  ) external initializer {
    __Controllable_init(controller_);
    _requireERC20(_rewardToken);
    _requireInterface(_ve, InterfaceIds.I_VE_TETU);

    uint _t = block.timestamp / WEEK * WEEK;
    startTime = _t;
    lastTokenTime = _t;
    timeCursor = _t;

    rewardToken = _rewardToken;
    ve = IVeTetu(_ve);

    IERC20(_rewardToken).safeApprove(_ve, type(uint).max);
  }

  // *************************************************************
  //                      CHECKPOINT
  // *************************************************************

  function checkpoint() external override {
    uint _period = activePeriod;
    // only trigger if new week
    if (block.timestamp >= _period + 1 weeks) {
      // set new period rounded to weeks
      activePeriod = block.timestamp / 1 weeks * 1 weeks;
      // checkpoint token balance that was just minted in veDist
      _checkpointToken();
      // checkpoint supply
      _checkpointTotalSupply();
    }
  }

  /// @dev Update tokensPerWeek value
  function _checkpointToken() internal {
    uint tokenBalance = IERC20(rewardToken).balanceOf(address(this));
    uint toDistribute = tokenBalance - tokenLastBalance;
    tokenLastBalance = tokenBalance;

    uint t = lastTokenTime;
    uint sinceLast = block.timestamp - t;
    lastTokenTime = block.timestamp;
    uint thisWeek = t / WEEK * WEEK;
    uint nextWeek = 0;

    // checkpoint should be called at least once per 20 weeks
    for (uint i = 0; i < 20; i++) {
      nextWeek = thisWeek + WEEK;
      if (block.timestamp < nextWeek) {
        tokensPerWeek[thisWeek] += adjustToDistribute(toDistribute, block.timestamp, t, sinceLast);
        break;
      } else {
        tokensPerWeek[thisWeek] += adjustToDistribute(toDistribute, nextWeek, t, sinceLast);
      }
      t = nextWeek;
      thisWeek = nextWeek;
    }
    emit CheckpointToken(block.timestamp, toDistribute);
  }

  /// @dev Adjust value based on time since last update
  function adjustToDistribute(
    uint toDistribute,
    uint t0,
    uint t1,
    uint sinceLast
  ) public pure returns (uint) {
    if (t0 <= t1 || t0 - t1 == 0 || sinceLast == 0) {
      return toDistribute;
    }
    return toDistribute * (t0 - t1) / sinceLast;
  }

  /// @dev Search in the loop given timestamp through ve points history.
  ///      Return minimal possible epoch.
  function findTimestampEpoch(IVeTetu _ve, uint _timestamp) public view returns (uint) {
    uint _min = 0;
    uint _max = _ve.epoch();
    for (uint i = 0; i < 128; i++) {
      if (_min >= _max) break;
      uint _mid = (_min + _max + 2) / 2;
      IVeTetu.Point memory pt = _ve.pointHistory(_mid);
      if (pt.ts <= _timestamp) {
        _min = _mid;
      } else {
        _max = _mid - 1;
      }
    }
    return _min;
  }

  /// @dev Search in the loop given timestamp through ve user points history.
  ///      Return minimal possible epoch.
  function findTimestampUserEpoch(
    IVeTetu _ve,
    uint tokenId,
    uint _timestamp,
    uint maxUserEpoch
  ) public view returns (uint) {
    uint _min = 0;
    uint _max = maxUserEpoch;
    for (uint i = 0; i < 128; i++) {
      if (_min >= _max) break;
      uint _mid = (_min + _max + 2) / 2;
      IVeTetu.Point memory pt = _ve.userPointHistory(tokenId, _mid);
      if (pt.ts <= _timestamp) {
        _min = _mid;
      } else {
        _max = _mid - 1;
      }
    }
    return _min;
  }

  /// @dev Return ve power at given timestamp
  function veForAt(uint _tokenId, uint _timestamp) external view returns (uint) {
    IVeTetu _ve = ve;
    uint maxUserEpoch = _ve.userPointEpoch(_tokenId);
    uint epoch = findTimestampUserEpoch(_ve, _tokenId, _timestamp, maxUserEpoch);
    IVeTetu.Point memory pt = _ve.userPointHistory(_tokenId, epoch);
    return uint(int256(_positiveInt128(pt.bias - pt.slope * (int128(int256(_timestamp - pt.ts))))));
  }

  /// @dev Call ve checkpoint and write veSupply at the current timeCursor
  function checkpointTotalSupply() external override {
    _checkpointTotalSupply();
  }

  function _checkpointTotalSupply() internal {
    IVeTetu _ve = ve;
    uint t = timeCursor;
    uint roundedTimestamp = block.timestamp / WEEK * WEEK;
    _ve.checkpoint();

    // assume will be called more frequently than 20 weeks
    for (uint i = 0; i < 20; i++) {
      if (t > roundedTimestamp) {
        break;
      } else {
        uint epoch = findTimestampEpoch(_ve, t);
        IVeTetu.Point memory pt = _ve.pointHistory(epoch);
        veSupply[t] = adjustVeSupply(t, pt.ts, pt.bias, pt.slope);
      }
      t += WEEK;
    }
    timeCursor = t;
  }

  /// @dev Calculate ve supply based on bias and slop for the given timestamp
  function adjustVeSupply(uint t, uint ptTs, int128 ptBias, int128 ptSlope) public pure returns (uint) {
    if (t < ptTs) {
      return 0;
    }
    int128 dt = int128(int256(t - ptTs));
    if (ptBias < ptSlope * dt) {
      return 0;
    }
    return uint(int256(_positiveInt128(ptBias - ptSlope * dt)));
  }

  // *************************************************************
  //                      CLAIM
  // *************************************************************

  /// @dev Return available to claim earned amount
  function claimable(uint _tokenId) external view returns (uint) {
    uint _lastTokenTime = lastTokenTime / WEEK * WEEK;
    ClaimCalculationResult memory result = _calculateClaim(_tokenId, ve, _lastTokenTime);
    return result.toDistribute;
  }

  /// @dev Claim rewards for given veID
  function claim(uint _tokenId) external override returns (uint) {
    IVeTetu _ve = ve;
    if (block.timestamp >= timeCursor) _checkpointTotalSupply();
    uint _lastTokenTime = lastTokenTime;
    _lastTokenTime = _lastTokenTime / WEEK * WEEK;
    uint amount = _claim(_tokenId, _ve, _lastTokenTime);
    if (amount != 0) {
      _ve.increaseAmount(rewardToken, _tokenId, amount);
      tokenLastBalance -= amount;
    }
    return amount;
  }

  /// @dev Claim rewards for given veIDs
  function claimMany(uint[] memory _tokenIds) external returns (bool) {
    if (block.timestamp >= timeCursor) _checkpointTotalSupply();
    uint _lastTokenTime = lastTokenTime;
    _lastTokenTime = _lastTokenTime / WEEK * WEEK;
    IVeTetu _votingEscrow = ve;
    uint total = 0;

    for (uint i = 0; i < _tokenIds.length; i++) {
      uint _tokenId = _tokenIds[i];
      if (_tokenId == 0) break;
      uint amount = _claim(_tokenId, _votingEscrow, _lastTokenTime);
      if (amount != 0) {
        _votingEscrow.increaseAmount(rewardToken, _tokenId, amount);
        total += amount;
      }
    }
    if (total != 0) {
      tokenLastBalance -= total;
    }

    return true;
  }

  function _claim(uint _tokenId, IVeTetu _ve, uint _lastTokenTime) internal returns (uint) {
    ClaimCalculationResult memory result = _calculateClaim(_tokenId, _ve, _lastTokenTime);
    if (result.success) {
      userEpochOf[_tokenId] = result.userEpoch;
      timeCursorOf[_tokenId] = result.weekCursor;
      emit Claimed(_tokenId, result.toDistribute, result.userEpoch, result.maxUserEpoch);
    }
    return result.toDistribute;
  }

  function _calculateClaim(
    uint _tokenId,
    IVeTetu _ve,
    uint _lastTokenTime
  ) internal view returns (ClaimCalculationResult memory) {
    uint userEpoch;
    uint maxUserEpoch = _ve.userPointEpoch(_tokenId);
    uint _startTime = startTime;

    if (maxUserEpoch == 0) {
      return ClaimCalculationResult(0, 0, 0, 0, false);
    }

    uint weekCursor = timeCursorOf[_tokenId];

    if (weekCursor == 0) {
      userEpoch = findTimestampUserEpoch(_ve, _tokenId, _startTime, maxUserEpoch);
    } else {
      userEpoch = userEpochOf[_tokenId];
    }

    if (userEpoch == 0) userEpoch = 1;

    IVeTetu.Point memory userPoint = _ve.userPointHistory(_tokenId, userEpoch);
    if (weekCursor == 0) {
      weekCursor = (userPoint.ts + WEEK - 1) / WEEK * WEEK;
    }
    if (weekCursor >= lastTokenTime) {
      return ClaimCalculationResult(0, 0, 0, 0, false);
    }
    if (weekCursor < _startTime) {
      weekCursor = _startTime;
    }

    return calculateToDistribute(
      _tokenId,
      weekCursor,
      _lastTokenTime,
      userPoint,
      userEpoch,
      maxUserEpoch,
      _ve
    );
  }

  function calculateToDistribute(
    uint _tokenId,
    uint weekCursor,
    uint _lastTokenTime,
    IVeTetu.Point memory userPoint,
    uint userEpoch,
    uint maxUserEpoch,
    IVeTetu _ve
  ) public view returns (ClaimCalculationResult memory) {
    IVeTetu.Point memory oldUserPoint;
    uint toDistribute;
    for (uint i = 0; i < 50; i++) {
      if (weekCursor >= _lastTokenTime) {
        break;
      }
      if (weekCursor >= userPoint.ts && userEpoch <= maxUserEpoch) {
        userEpoch += 1;
        oldUserPoint = userPoint;
        if (userEpoch > maxUserEpoch) {
          userPoint = IVeTetu.Point(0, 0, 0, 0);
        } else {
          userPoint = _ve.userPointHistory(_tokenId, userEpoch);
        }
      } else {
        int128 dt = int128(int256(weekCursor - oldUserPoint.ts));
        uint balanceOf = uint(int256(_positiveInt128(oldUserPoint.bias - dt * oldUserPoint.slope)));
        if (balanceOf == 0 && userEpoch > maxUserEpoch) {
          break;
        }
        toDistribute += balanceOf * tokensPerWeek[weekCursor] / veSupply[weekCursor];
        weekCursor += WEEK;
      }
    }
    return ClaimCalculationResult(
      toDistribute,
      Math.min(maxUserEpoch, userEpoch - 1),
      weekCursor,
      maxUserEpoch,
      true
    );
  }

  function _positiveInt128(int128 value) internal pure returns (int128) {
    return value < 0 ? int128(0) : value;
  }

  /// @dev Block timestamp rounded to weeks
  function timestamp() external view returns (uint) {
    return block.timestamp / WEEK * WEEK;
  }

  /// @dev See {IERC165-supportsInterface}.
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == InterfaceIds.I_VE_DISTRIBUTOR || super.supportsInterface(interfaceId);
  }

}
