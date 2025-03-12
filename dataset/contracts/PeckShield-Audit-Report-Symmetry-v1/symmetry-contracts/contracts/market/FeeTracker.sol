// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../utils/Initializable.sol";
import "../utils/SafeDecimalMath.sol";
import "../utils/SignedSafeDecimalMath.sol";
import "../utils/CommonContext.sol";

import "../interfaces/IMarketSettings.sol";
import "../interfaces/IFeeTracker.sol";
import "../interfaces/IPerpTracker.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/IMarket.sol";
import "../interfaces/IMarginTracker.sol";
import "../interfaces/IVotingEscrow.sol";
import "../interfaces/ITradingFeeCoupon.sol";
import "../interfaces/ICouponStaking.sol";

import "./MarketSettingsContext.sol";

contract FeeTracker is IFeeTracker, CommonContext, MarketSettingsContext, AccessControlEnumerable, Initializable {
    using SafeERC20 for IERC20;
    using SafeDecimalMath for uint;
    using SignedSafeDecimalMath for int;
    using SafeCast for uint;
    using SafeCast for int;

    // reserved storage slots for base contract upgrade in future
    uint[50] private __gap;

    // states
    address public market; // market
    address public perpTracker; // perpetual position tracker
    address public settings; // settings for markets
    address public votingEscrow; // voting escrow
    address public coupon;

    Tier[] public tradingFeeTiers; // trading fee tiers, in decending order

    mapping(uint => uint) public tradingFeeIncentives;
    mapping(address => uint) public claimedWeekCursor;
    uint public incentiveStartTime;
    mapping(uint => uint) public veSupply;
    uint public incentiveWeekCursor; // week cursor of veSYM total supply snapshot

    address public couponStaking;

    modifier onlyMarket() {
        require(msg.sender == market, "FeeTracker: sender is not market");
        _;
    }

    /*=== initialize ===*/
    function initialize(
        address _market,
        address _perpTracker,
        address _coupon,
        address _votingEscrow
    ) external onlyInitializeOnce {
        market = _market;
        perpTracker = _perpTracker;
        coupon = _coupon;
        settings = IMarket(_market).settings();
        votingEscrow = _votingEscrow;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /*=== owner functions ===*/

    function setTradingFeeTiers(Tier[] memory _tiers) external onlyRole(DEFAULT_ADMIN_ROLE) {
        delete tradingFeeTiers;

        uint len = _tiers.length;
        for (uint i = 0; i < len; ++i) {
            if (i > 0) {
                require(_tiers[i - 1].portion > _tiers[i].portion, "FeeTracker: tier not decreasing");
            }
            tradingFeeTiers.push(_tiers[i]);
        }
    }

    function setCouponStaking(address _couponStaking) external onlyRole(DEFAULT_ADMIN_ROLE) {
        couponStaking = _couponStaking;
    }

    /*=== discount === */

    function _vePortionOf(address _account) internal view returns (uint) {
        IVotingEscrow votingEscrow_ = IVotingEscrow(votingEscrow);

        uint totalSupply = votingEscrow_.totalSupply();
        if (totalSupply > 0) {
            return votingEscrow_.balanceOf(_account).divideDecimal(totalSupply);
        }
        return 0;
    }

    function _mergeDiscount(uint _d0, uint _d1) internal pure returns (uint) {
        if (_d0 == 0) return _d1;
        if (_d1 == 0) return _d0;
        return _UNSIGNED_UNIT - (_UNSIGNED_UNIT - _d0).multiplyDecimal(_UNSIGNED_UNIT - _d1);
    }

    function tradingFeeDiscount(address _account) public view returns (uint discount) {
        uint portion = _vePortionOf(_account);
        uint len = tradingFeeTiers.length;
        for (uint i = 0; i < len; ++i) {
            if (portion >= tradingFeeTiers[i].portion) {
                discount = tradingFeeTiers[i].discount;
                break;
            }
        }
        if (couponStaking != address(0)) {
            discount = _mergeDiscount(discount, ICouponStaking(couponStaking).getDiscount(_account));
        }
    }

    /*=== perp trading fee ===*/

    function getTradingFee(
        address _account,
        int _sizeDelta,
        int _price,
        bool _isTaker
    ) external view returns (uint fee, uint couponUsed) {
        int k = IMarketSettings(settings).getIntVals(_isTaker ? PERP_TAKER_FEE : PERP_MAKER_FEE);
        // apply fee discount
        k = k.multiplyDecimal(_UNIT - tradingFeeDiscount(_account).toInt256());
        require(k < _UNIT, "FeeTracker: trading fee ratio > 1");
        fee = _price.multiplyDecimal(_sizeDelta.abs()).multiplyDecimal(k).toUint256();
        // use coupons
        ITradingFeeCoupon coupon_ = ITradingFeeCoupon(coupon);

        couponUsed = IMarketSettings(settings).getIntVals(MAX_COUPON_DEDUCTION_RATIO).toUint256().multiplyDecimal(fee);
        couponUsed = coupon_.unspents(_account).min(couponUsed);
    }

    function liquidationPenalty(int notional) external view returns (int) {
        int liquidationPenaltyRatio = IMarketSettings(settings).getIntVals(LIQUIDATION_PENALTY_RATIO);
        return notional.abs().multiplyDecimal(liquidationPenaltyRatio);
    }

    function liquidationFee(int notional) external view returns (int) {
        int liquidationFeeRatio = IMarketSettings(settings).getIntVals(LIQUIDATION_FEE_RATIO);
        int fee = notional.abs().multiplyDecimal(liquidationFeeRatio);
        int minFee = IMarketSettings(settings).getIntVals(MIN_LIQUIDATION_FEE);
        int maxFee = IMarketSettings(settings).getIntVals(MAX_LIQUIDATION_FEE);
        return fee.max(minFee).min(maxFee);
    }

    /*=== fee incentives ===*/
    function distributeIncentives(uint _fee) external onlyMarket {
        if (incentiveStartTime == 0) {
            uint t = _startOfWeek(block.timestamp);
            incentiveStartTime = t;
        }
        if (incentiveWeekCursor == 0) {
            incentiveWeekCursor = incentiveStartTime;
        }
        tradingFeeIncentives[_startOfWeek(block.timestamp)] += _fee;
    }

    function _findUserStartWeek(address _addr) internal view returns (uint startWeek) {
        IVotingEscrow votingEscrow_ = IVotingEscrow(votingEscrow);
        uint lockStartTime = type(uint).max;
        uint stakeStartTime = type(uint).max;
        {
            uint lockEpoch = votingEscrow_.userPointEpoch(_addr);
            if (lockEpoch > 0) {
                lockStartTime = votingEscrow_.userPointHistory(_addr, 1).ts;
            }
        }
        {
            uint stakedEpoch = votingEscrow_.userStakedEpoch(_addr);
            if (stakedEpoch > 0) {
                stakeStartTime = votingEscrow_.userStakedHistory(_addr, 1).ts;
            }
        }
        startWeek = lockStartTime < stakeStartTime ? lockStartTime : stakeStartTime;
        if (startWeek == type(uint).max) {
            startWeek = 0;
        } else {
            startWeek = _startOfWeek(startWeek + 1 weeks - 1);
        }
    }

    function _snapshotTotalSupply() internal {
        IVotingEscrow votingEscrow_ = IVotingEscrow(votingEscrow);
        uint cursor = incentiveWeekCursor;
        uint currentWeek = _startOfWeek(block.timestamp);
        votingEscrow_.checkpoint();

        for (uint i = 0; i < 20; ++i) {
            if (cursor > currentWeek) {
                break;
            }
            veSupply[cursor] = votingEscrow_.totalSupplyAt(cursor);
            cursor += 1 weeks;
        }
        incentiveWeekCursor = cursor;
    }

    function snapshotTotalSupply() external {
        _snapshotTotalSupply();
    }

    function claimIncentives(address _account) external returns (uint) {
        return _claimIncentives(_account);
    }

    function _claimIncentives(address _account) internal returns (uint) {
        if (incentiveStartTime == 0) {
            return 0;
        }
        // calculate the maximum week(exclusive) that can claim
        uint maxWeek = _startOfWeek(block.timestamp);
        if (maxWeek >= incentiveWeekCursor) {
            _snapshotTotalSupply();
        }
        maxWeek = maxWeek.min(incentiveWeekCursor);
        // calculate week to start claim
        uint weekCursor = claimedWeekCursor[_account];
        if (weekCursor == 0) {
            weekCursor = _findUserStartWeek(_account);
            if (weekCursor == 0) {
                return 0;
            }
        }
        if (incentiveStartTime > weekCursor) {
            weekCursor = incentiveStartTime;
        }
        IVotingEscrow votingEscrow_ = IVotingEscrow(votingEscrow);
        // calculate user point at start week
        // user lock point
        LockedIterator memory lockedIter;
        lockedIter.maxEpoch = votingEscrow_.userPointEpoch(_account);
        lockedIter.locked = votingEscrow_.lockedPointOfAt(_account, weekCursor); // the locked point at weekCursor
        lockedIter.nextEpoch = votingEscrow_.findUserPoint(_account, weekCursor) + 1;
        if (lockedIter.nextEpoch <= lockedIter.maxEpoch) {
            lockedIter.newLocked = votingEscrow_.userPointHistory(_account, lockedIter.nextEpoch);
        }
        // user staked point
        StakedIterator memory stakedIter;
        stakedIter.maxEpoch = votingEscrow_.userStakedEpoch(_account);
        stakedIter.nextEpoch = votingEscrow_.findUserStaked(_account, weekCursor);
        if (stakedIter.nextEpoch > 0) {
            stakedIter.staked = votingEscrow_.userStakedHistory(_account, stakedIter.nextEpoch);
        }
        ++stakedIter.nextEpoch;
        if (stakedIter.nextEpoch <= stakedIter.maxEpoch) {
            stakedIter.newStaked = votingEscrow_.userStakedHistory(_account, stakedIter.nextEpoch);
        }
        // iteration
        uint toClaim = 0;
        for (uint i = 0; i < 50; ++i) {
            if (weekCursor >= maxWeek) {
                break;
            }
            if (lockedIter.nextEpoch <= lockedIter.maxEpoch && weekCursor >= lockedIter.newLocked.ts) {
                // move locked point forward
                lockedIter.locked = lockedIter.newLocked;
                ++lockedIter.nextEpoch;
                if (lockedIter.nextEpoch <= lockedIter.maxEpoch) {
                    lockedIter.newLocked = votingEscrow_.userPointHistory(_account, lockedIter.nextEpoch);
                }
            } else if (stakedIter.nextEpoch <= stakedIter.maxEpoch && weekCursor >= stakedIter.newStaked.ts) {
                // move staked point forward
                stakedIter.staked = stakedIter.newStaked;
                ++stakedIter.nextEpoch;
                if (stakedIter.nextEpoch <= stakedIter.maxEpoch) {
                    stakedIter.newStaked = votingEscrow_.userStakedHistory(_account, stakedIter.nextEpoch);
                }
            } else {
                // calculate week incentive
                if (veSupply[weekCursor] > 0 && tradingFeeIncentives[weekCursor] > 0) {
                    int128 balance = lockedIter.locked.bias -
                        SafeCast.toInt128(int(weekCursor - lockedIter.locked.ts)) *
                        lockedIter.locked.slope;
                    if (balance < 0) balance = 0;
                    toClaim +=
                        (tradingFeeIncentives[weekCursor] *
                            (SafeCast.toUint256(balance) +
                                votingEscrow_.stakedBalance(stakedIter.staked, weekCursor))) /
                        veSupply[weekCursor];
                }
                // update locked point
                if (lockedIter.locked.ts < weekCursor) {
                    lockedIter.locked.bias -=
                        lockedIter.locked.slope *
                        SafeCast.toInt128(int(weekCursor - lockedIter.locked.ts));
                    lockedIter.locked.slope += votingEscrow_.userSlopeChanges(_account, weekCursor);
                    lockedIter.locked.ts = weekCursor;
                }
                // move week cursor forward
                weekCursor += 1 weeks;
            }
        }
        claimedWeekCursor[_account] = weekCursor;
        if (toClaim > 0) {
            IMarket market_ = IMarket(market);
            market_.allocateIncentives(msg.sender, toClaim.toInt256());
            emit Claimed(msg.sender, weekCursor, toClaim);
        }
        return toClaim;
    }
}
