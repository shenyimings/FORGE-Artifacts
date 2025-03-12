// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";
import "./libs/SafeMath.sol";
import "./libs/Ownable.sol";
import "./libs/ReentrancyGuard.sol";

interface IMintableERC20 is IBEP20 {
    function mint(address _to, uint256 _amount) external;
}

// Cafeteria is the master of Coupon. He can make Coupon and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once Coupon is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract Cafeteria is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        uint256 lockedReward;
        //
        // We do some fancy math here. Basically, any point in time, the amount of COUPONs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accCouponPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accCouponPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. COUPONs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that COUPONs distribution occurs.
        uint256 accCouponPerShare;   // Accumulated COUPONs per share, times 1e12. See below.
        uint16 depositFeeBP;      // Deposit fee in basis points
        bool withdrawFee100;      // Deposit fee in basis points
    }

    // The Coupon TOKEN!
    IMintableERC20 public coupon;
    // Dev address.
    address public devaddr;
    // Coupon tokens created per block.
    uint256 public couponPerBlock;
    // Bonus multiplier for early coupon makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    // Deposit Fee address
    address public feeAddress;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when Coupon mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event SetFeeAddress(address indexed user, address indexed newAddress);
    event SetDevAddress(address indexed user, address indexed newAddress);
    event UpdateEmissionRate(address indexed user, uint256 goosePerBlock);

    constructor(
        address _coupon,
        address _devaddr,
        address _feeAddress,
        uint256 _couponPerBlock,
        uint256 _startBlock
    ) public {
        coupon = IMintableERC20(_coupon);
        devaddr = _devaddr;
        feeAddress = _feeAddress;
        couponPerBlock = _couponPerBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    mapping (IBEP20 => bool) public poolExistence;
    modifier nonDuplicated(IBEP20 _lpToken) {
        require(poolExistence[_lpToken] == false, "duplicated");
        _;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IBEP20 _lpToken, uint16 _depositFeeBP, bool _withdrawFee100, bool _withUpdate) public onlyOwner nonDuplicated(_lpToken) {
        require(_depositFeeBP <= 10000, "invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolExistence[_lpToken] = true;
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accCouponPerShare: 0,
            depositFeeBP: _depositFeeBP,
            withdrawFee100: _withdrawFee100
        }));
    }

    // Update the given pool's Coupon allocation point and deposit fee. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 10000, "invalid deposit fee basis points");

        if (_withUpdate) {
            massUpdatePools();
        }

        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;

        // For emergency fix of 100% withdrawal fee
        if (_allocPoint == 0) {
            poolExistence[poolInfo[_pid].lpToken] = false;
        } else {
            poolExistence[poolInfo[_pid].lpToken] = true;
        }
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending COUPONs on frontend.
    function pendingCoupon(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accCouponPerShare = pool.accCouponPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 couponReward = multiplier.mul(couponPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accCouponPerShare = accCouponPerShare.add(couponReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accCouponPerShare).div(1e12).sub(user.rewardDebt) + user.lockedReward;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 couponReward = multiplier.mul(couponPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        coupon.mint(devaddr, couponReward.div(10));
        coupon.mint(address(this), couponReward);
        pool.accCouponPerShare = pool.accCouponPerShare.add(couponReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to Cafeteria for Coupon allocation.
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        uint256 pending = user.amount.mul(pool.accCouponPerShare).div(1e12).sub(user.rewardDebt) + user.lockedReward;
        if (pending > 0) {
            if (_amount == 0 || !pool.withdrawFee100) {
                safeCouponTransfer(msg.sender, pending);
                user.lockedReward = 0;
            } else {
                user.lockedReward = pending;
            }
        }

        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            if (pool.depositFeeBP > 0){
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
                pool.lpToken.safeTransfer(feeAddress, depositFee);
                user.amount = user.amount.add(_amount).sub(depositFee);
            } else {
                user.amount = user.amount.add(_amount);
            }
        } else if (pool.withdrawFee100){
            pool.lpToken.safeTransfer(feeAddress, user.amount);
            user.amount = 0;
        }
        user.rewardDebt = user.amount.mul(pool.accCouponPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from Cafeteria.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "invalid amount");
        require(!pool.withdrawFee100, "harvest only");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accCouponPerShare).div(1e12).sub(user.rewardDebt) + user.lockedReward;
        if (pending > 0) {
            safeCouponTransfer(msg.sender, pending);
            user.lockedReward = 0;
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accCouponPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        user.lockedReward = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe coupon transfer function, just in case if rounding error causes pool to not have enough COUPONs.
    function safeCouponTransfer(address _to, uint256 _amount) internal {
        uint256 couponBal = coupon.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > couponBal) {
            transferSuccess = coupon.transfer(_to, couponBal);
        } else {
            transferSuccess = coupon.transfer(_to, _amount);
        }
        require(transferSuccess, "transfer failed");
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
        emit SetDevAddress(msg.sender, _devaddr);
    }

    function setFeeAddress(address _feeAddress) public {
        require(msg.sender == feeAddress, "nope");
        feeAddress = _feeAddress;
        emit SetFeeAddress(msg.sender, _feeAddress);
    }

    // Foodcourt has to add hidden dummy pools inorder to alter the emission, here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _couponPerBlock) public onlyOwner {
        massUpdatePools();
        couponPerBlock = _couponPerBlock;
        emit UpdateEmissionRate(msg.sender, _couponPerBlock);
    }
}
