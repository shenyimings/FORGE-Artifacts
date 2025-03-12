// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../utils/SafeDecimalMath.sol";
import "../utils/SignedSafeDecimalMath.sol";
import "../utils/Initializable.sol";
import "../utils/CommonContext.sol";

import "../interfaces/IMarket.sol";
import "../interfaces/IVolumeTracker.sol";
import "../interfaces/ITradingFeeCoupon.sol";

import "./MarketSettings.sol";
import "./MarketSettingsContext.sol";

contract VolumeTracker is IVolumeTracker, CommonContext, MarketSettingsContext, AccessControlEnumerable, Initializable {
    using SafeDecimalMath for uint;
    using SignedSafeDecimalMath for int;
    using SafeCast for uint;
    using SafeCast for int;

    // reserved storage slots for base contract upgrade in future
    uint[50] private __gap;

    // states
    address public market;
    address public settings;
    address public coupon;

    mapping(address => mapping(uint => uint)) public userWeeklyVolume;
    mapping(address => mapping(uint => uint)) public userDailyVolume;

    mapping(address => mapping(uint => bool)) public weeklyCouponClaimed;

    address public luckyNumberAnnouncer;
    mapping(uint => uint) public luckyCandidates;
    mapping(uint => uint) public luckyNumberIssuedAt;
    mapping(uint => uint) public luckyNumber;
    mapping(address => mapping(uint => uint)) public userLuckyNumber;

    Tier[] public rebateTiers; // trading fee rebate tiers

    /*=== modifers ===*/
    modifier onlyMarket() {
        require(msg.sender == market, "PerpTracker: sender is not market");
        _;
    }

    function initialize(address _market, address _coupon) external onlyInitializeOnce {
        market = _market;
        coupon = _coupon;
        settings = IMarket(_market).settings();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /*=== owner ===*/

    function setLuckyNumberAnnouncer(address _announcer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        luckyNumberAnnouncer = _announcer;
    }

    function setRebateTiers(Tier[] memory _tiers) external onlyRole(DEFAULT_ADMIN_ROLE) {
        delete rebateTiers;

        uint len = _tiers.length;
        for (uint i = 0; i < len; ++i) {
            if (i > 0) {
                require(_tiers[i - 1].requirement > _tiers[i].requirement, "VolumeTracker: tier not decreasing");
            }
            rebateTiers.push(_tiers[i]);
        }
    }

    /*=== volume ===*/
    function logTrade(address _account, uint _volume) external onlyMarket {
        _addDailyVolume(_account, _volume);
        _addWeeklyVolume(_account, _volume);
    }

    function _addDailyVolume(address _account, uint _volume) internal {
        IMarketSettings settings_ = IMarketSettings(settings);

        uint t = _startOfDay(block.timestamp);
        uint totalVol = userDailyVolume[_account][t] + _volume;
        uint oneDraw = uint(settings_.getIntVals(ONE_DRAW_REQUIREMENT));
        uint newDraws = totalVol / oneDraw - userDailyVolume[_account][t] / oneDraw;
        userDailyVolume[_account][t] = totalVol;

        for (uint i = 0; i < 10; ++i) {
            if (newDraws == 0) {
                break;
            }
            if (userLuckyNumber[_account][t] == 0) {
                uint num = luckyCandidates[t] + 1;
                luckyCandidates[t] = num;
                userLuckyNumber[_account][t] = num;
                --newDraws;
            }
            t += 1 days;
        }
    }

    function _addWeeklyVolume(address _account, uint _volume) internal {
        uint t = _startOfWeek(block.timestamp);
        uint vol = userWeeklyVolume[_account][t] + _volume;
        userWeeklyVolume[_account][t] = vol;

        emit WeeklyVolumeUpdated(_account, t, vol);
    }

    /*=== weekly trading fee coupon ===*/
    function _rebateRatio(uint _volume) internal view returns (uint) {
        uint len = rebateTiers.length;
        for (uint i = 0; i < len; ++i)
            if (_volume >= rebateTiers[i].requirement) {
                return rebateTiers[i].rebateRatio;
            }
        return 0;
    }

    function _claimWeeklyTradingFeeCoupon(uint _t) internal returns (uint value) {
        _t = _startOfWeek(_t);
        require(_t < _startOfWeek(block.timestamp), "VolumeTracker: invalid date");

        require(!weeklyCouponClaimed[msg.sender][_t], "VolumeTracker: claimed already");
        weeklyCouponClaimed[msg.sender][_t] = true;

        uint luckyNum = luckyNumber[_t + 6 * 1 days];
        require(luckyNum != 0, "VolumeTracker: not determined");

        uint volume = userWeeklyVolume[msg.sender][_t];
        uint rebateRatio = _rebateRatio(volume);
        if (rebateRatio > 0) {
            value =
                (IMarketSettings(settings)
                    .getIntVals(PERP_TAKER_FEE)
                    .toUint256()
                    .multiplyDecimal(volume)
                    .multiplyDecimal(rebateRatio) / _UNSIGNED_UNIT) *
                _UNSIGNED_UNIT;
            uint minValue = IMarketSettings(settings).getIntVals(MIN_COUPON_VALUE).toUint256();
            if (value > 0 && value >= minValue) {
                ITradingFeeCoupon(coupon).mintCoupon(
                    msg.sender,
                    value,
                    uint(keccak256(abi.encodePacked(luckyNum, msg.sender, "weekly")))
                );
            }
            emit WeeklyCouponClaimed(msg.sender, _t);
        } else {
            revert("VolumeTracker: no chance");
        }
    }

    function claimWeeklyTradingFeeCoupon(uint[] memory _t) external returns (uint value) {
        uint len = _t.length;
        for (uint i = 0; i < len; ++i) {
            value += _claimWeeklyTradingFeeCoupon(_t[i]);
        }
    }

    /*=== I'm feeling lucky ===*/
    function issueLuckyNumber(uint _t) external {
        _t = _startOfDay(_t).min(_startOfDay(block.timestamp) - 1 days);
        require(luckyNumberIssuedAt[_t] == 0, "VolumeTracker: issued");
        luckyNumberIssuedAt[_t] = block.number;
    }

    function _computeLuckyNumber(bytes32 _h1, bytes32 _h2, bytes32 _h3) internal pure returns (uint) {
        return uint(keccak256(abi.encodePacked(_h1, _h2, _h3))) + 1; // +1 to make it > 0
    }

    function _drawLuckyNumber(uint _t) internal returns (bool, RevertReason) {
        if (luckyNumber[_t] != 0) {
            return (false, RevertReason.DRAWED);
        }
        uint issuedAt = luckyNumberIssuedAt[_t];
        if (issuedAt == 0) {
            return (false, RevertReason.NOT_ISSUED);
        }
        bytes32 h1 = blockhash(issuedAt + 1);
        bytes32 h2 = blockhash(issuedAt + 2);
        bytes32 h3 = blockhash(issuedAt + 3);
        if (h1 == 0x0 || h2 == 0x0 || h3 == 0x0) {
            return (false, RevertReason.HASH_UNAVAILABLE);
        }
        luckyNumber[_t] = _computeLuckyNumber(h1, h2, h3);
        return (true, RevertReason.EMPTY);
    }

    function _drawRevertReason(RevertReason reason) internal pure returns (string memory) {
        if (reason == RevertReason.DRAWED) {
            return "VolumeTracker: drawed";
        } else if (reason == RevertReason.NOT_ISSUED) {
            return "VolumeTracker: not issued";
        } else {
            return "VolumeTracker: hash unavailable";
        }
    }

    function drawLuckyNumber(uint _t) external {
        _t = _startOfDay(_t).min(_startOfDay(block.timestamp) - 1 days);
        (bool ok, RevertReason reason) = _drawLuckyNumber(_t);
        if (!ok) {
            revert(_drawRevertReason(reason));
        }
    }

    function drawLuckyNumberByAnnouncer(uint _t, bytes32 _h1, bytes32 _h2, bytes32 _h3) external {
        require(msg.sender == luckyNumberAnnouncer, "VolumeTracker: forbid");
        _t = _startOfDay(_t).min(_startOfDay(block.timestamp) - 1 days);
        (bool ok, RevertReason reason) = _drawLuckyNumber(_t);
        if (!ok) {
            if (reason != RevertReason.HASH_UNAVAILABLE) {
                revert(_drawRevertReason(reason));
            }
            require(luckyNumberIssuedAt[_t] < block.number - 3, "VolumeTracker: too early");
            luckyNumber[_t] = _computeLuckyNumber(_h1, _h2, _h3);
        }
    }

    function claimLuckyCoupon() external {
        uint _t = _startOfDay(block.timestamp) - 1 days;

        uint num = userLuckyNumber[msg.sender][_t];
        require(num > 0, "VolumeTracker: no chance");
        uint luckyNum = luckyNumber[_t];
        require(luckyNum != 0, "VolumeTracker: not determined");
        userLuckyNumber[msg.sender][_t] = 0;
        require(num % 10 == luckyNum % 10, "VolumeTracker: no prize");
        ITradingFeeCoupon(coupon).mintCoupon(
            msg.sender,
            uint(MarketSettings(settings).getIntVals(ONE_DRAW_REWARD)),
            uint(keccak256(abi.encodePacked(luckyNum, msg.sender, "lucky")))
        );
    }
}
