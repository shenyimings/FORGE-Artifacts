// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../interfaces/INFTDescriptor.sol";
import "../interfaces/ITradingFeeCoupon.sol";
import "../interfaces/ICouponStaking.sol";

import "../utils/Initializable.sol";

contract CouponStaking is ICouponStaking, AccessControlEnumerable, Initializable {
    // reserved storage slots for base contract upgrade in future
    uint[50] private __gap;

    // discount end timestamp
    uint public immutable DISCOUNT_START;
    uint public immutable DISCOUNT_END;

    address public coupon;
    mapping(address => uint[]) private staked;
    mapping(address => Discount) private discounts;

    constructor(uint _start, uint _end) {
        DISCOUNT_START = _start;
        DISCOUNT_END = _end;
    }

    function initialize(address _admin, address _coupon) external onlyInitializeOnce {
        coupon = _coupon;

        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function getStaked(address _account) external view returns (uint[] memory) {
        return staked[_account];
    }

    /*=== stake ===*/

    function _computeDiscount(address _account) internal view returns (uint) {
        uint[] memory coupons = staked[_account];
        ITradingFeeCoupon coupon_ = ITradingFeeCoupon(coupon);
        INFTDescriptor descriptor_ = INFTDescriptor(coupon_.descriptor());
        uint cnt = 0;
        for (uint i = 0; i < coupons.length; ++i) {
            INFTDescriptor.TokenURIParams memory params = coupon_.tokenURIParams(coupons[i]);
            if (descriptor_.getSymbolNum(params.tokenSalt) < 12) {
                cnt += 1;
            }
        }
        if (cnt >= 6) return 2e17;
        return 0;
    }

    function _snapshotDiscount(address _account) internal {
        Discount storage discount = discounts[_account];
        discount.ts = block.timestamp;
        discount.discount = _computeDiscount(_account);
    }

    function stake(uint[] memory _ids) external {
        require(
            (block.timestamp >= DISCOUNT_START && block.timestamp <= DISCOUNT_END) || _ids.length == 0,
            "CouponStaking: not now"
        );

        IERC721 coupon_ = IERC721(coupon);

        uint[] memory old = staked[msg.sender];
        for (uint i = 0; i < old.length; ++i) {
            coupon_.safeTransferFrom(address(this), msg.sender, old[i]);
        }
        for (uint i = 0; i < _ids.length; ++i) {
            coupon_.safeTransferFrom(msg.sender, address(this), _ids[i]);
        }
        staked[msg.sender] = _ids;
        _snapshotDiscount(msg.sender);
        require(_ids.length == 0 || discounts[msg.sender].discount > 0, "CouponStaking: cannot get discount");
    }

    /*=== campaigns ===*/

    function getDiscount(address _account) external view returns (uint) {
        Discount memory discount = discounts[_account];
        return
            discount.ts >= DISCOUNT_START &&
                discount.ts <= DISCOUNT_END &&
                block.timestamp >= DISCOUNT_START &&
                block.timestamp <= DISCOUNT_END
                ? discount.discount
                : 0;
    }
}
