// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IStrategy.sol";

// Mint
abstract contract FRXToken is ERC20 {
    function mint(address _to, uint256 _amount) public virtual;
}

contract FrxFarm is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 shares; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.

        uint256 distributionDebt;

        // We do some fancy math here. Basically, any point in time, the amount of AUTO
        // entitled to a user but is pending to be distributed is:
        //
        //   amount = user.shares / sharesTotal * wantLockedTotal
        //   pending reward = (amount * pool.accFRXPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws want tokens to a pool. Here's what happens:
        //   1. The pool's `accFRXPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    struct PoolInfo {
        IERC20 want; // Address of the want token.
        uint256 allocPoint; // How many allocation points assigned to this pool. FRX to distribute per block.
        uint256 lastRewardBlock; // Last block number that FRX distribution occurs.
        uint256 accFRXPerShare; // Accumulated FRX per share, times 1e8. See below.
        uint256 distributionDebt;
        address strat; // Strategy address that will auto compound want tokens
    }

    // Token address
    address public constant FRX = 0x30C980d9bb2bE78181C56f6A4a8577cA343036E4;
    // Owner reward per block: 10%
    uint256 public constant ownerFRXReward = 1000;
    // Frx total supply: 200 mil = 200000000e8
    uint256 public constant FRXMaxSupply = 200000000e8;
    // Frxs per block: (1e18 - owner 10%)
    uint256 public constant FRXPerBlock = 9e8; // FRX tokens created per block
    // Approx 30/4/2021
    uint256 public constant startBlock = 6996000; // https://bscscan.com/block/countdown/6996000

    uint256 public constant distributionBP = 100; // 1% distribute to all investor in same farm

    PoolInfo[] public poolInfo; // Info of each pool.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo; // Info of each user that stakes LP tokens.
    uint256 public totalAllocPoint = 0; // Total allocation points. Must be the sum of all allocation points in all pools.

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do. (Only if want tokens are stored here.)
    function add(
        uint256 _allocPoint,
        IERC20 _want,
        bool _withUpdate,
        address _strat
    ) public onlyOwner {
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                want : _want,
                allocPoint : _allocPoint,
                lastRewardBlock : lastRewardBlock,
                accFRXPerShare : 0,
                distributionDebt: 0,
                strat : _strat
            })
        );

        if (_withUpdate) {
            massUpdatePools();
        }
    }

    // Update the given pool's FRX allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) internal view returns (uint256) {
        if (IERC20(FRX).totalSupply() >= FRXMaxSupply) {
            return 0;
        }
        return _to.sub(_from);
    }

    // View function to see pending AUTO on frontend.
    function pendingFRX(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accFRXPerShare = pool.accFRXPerShare;
        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        if (block.number > pool.lastRewardBlock && sharesTotal != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            accFRXPerShare = accFRXPerShare.add(multiplier.mul(FRXPerBlock).mul(pool.allocPoint).mul(1e8).div(totalAllocPoint).div(sharesTotal));
        }
        return user.shares.mul(accFRXPerShare).div(1e8).sub(user.rewardDebt);
    }

    // View function to see staked Want tokens on frontend.
    function stakedWantTokens(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        uint256 wantLockedTotal =
        IStrategy(poolInfo[_pid].strat).wantLockedTotal();
        if (sharesTotal == 0) {
            return 0;
        }
        return user.shares.mul(wantLockedTotal).div(sharesTotal);
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
        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        if (sharesTotal == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        if (multiplier <= 0) {
            return;
        }
        uint256 FRXReward = multiplier.mul(FRXPerBlock).mul(pool.allocPoint);

        pool.accFRXPerShare = pool.accFRXPerShare.add(FRXReward.mul(1e8).div(totalAllocPoint).div(sharesTotal));
        pool.lastRewardBlock = block.number;

        FRXToken(FRX).mint(owner(), FRXReward.mul(ownerFRXReward).div(totalAllocPoint).div(10000));
        FRXToken(FRX).mint(address(this), FRXReward.div(totalAllocPoint));
    }

    function syncUser(address _user, uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        user.shares = user.shares.add(pool.distributionDebt.sub(user.distributionDebt).mul(user.shares).div(1e8));
        user.distributionDebt = pool.distributionDebt;
    }

    // Want tokens moved from user -> AUTOFarm (AUTO allocation) -> Strat (compounding)
    function deposit(uint256 _pid, uint256 _wantAmt) public nonReentrant {
        updatePool(_pid);
        syncUser(msg.sender, _pid);
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if (user.shares > 0) {
            uint256 pending = user.shares.mul(pool.accFRXPerShare).div(1e8).sub(user.rewardDebt);

            if (pending > 0) {
                safeFRXTransfer(msg.sender, pending);
            }
        }
        if (_wantAmt > 0) {
            IStrategy strat = IStrategy(poolInfo[_pid].strat);
            uint _finalWantAmt = _wantAmt;

            if (strat.sharesTotal() > 0 ) {
                uint256 distributionAmount = _wantAmt.mul(distributionBP).div(10000);
                pool.distributionDebt = pool.distributionDebt.add(distributionAmount.div(strat.sharesTotal().div(1e8)));
                _finalWantAmt = _wantAmt.sub(distributionAmount);
            }

            pool.want.safeIncreaseAllowance(pool.strat, _finalWantAmt);
            uint256 sharesAdded = strat.deposit(msg.sender, _finalWantAmt);
            user.shares = user.shares.add(sharesAdded);
            pool.want.safeTransferFrom(address(msg.sender), address(this), _wantAmt);
        }

        user.rewardDebt = user.shares.mul(pool.accFRXPerShare).div(1e8);
        emit Deposit(msg.sender, _pid, _wantAmt);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _wantAmt) public nonReentrant {
        updatePool(_pid);
        syncUser(msg.sender, _pid);
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strat).wantLockedTotal();
        uint256 sharesTotal = IStrategy(poolInfo[_pid].strat).sharesTotal();

        require(user.shares > 0, "user.shares is 0");
        require(sharesTotal > 0, "sharesTotal is 0");

        // Withdraw pending AUTO
        uint256 pending = user.shares.mul(pool.accFRXPerShare).div(1e8).sub(user.rewardDebt);

        // Withdraw want tokens
        uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);
        if (_wantAmt > amount) {
            _wantAmt = amount;
        }

        if (_wantAmt > 0) {
            uint256 sharesRemoved = IStrategy(poolInfo[_pid].strat).withdraw(msg.sender, _wantAmt);

            if (sharesRemoved > user.shares) {
                user.shares = 0;
            } else {
                user.shares = user.shares.sub(sharesRemoved);
            }

            uint256 wantBal = IERC20(pool.want).balanceOf(address(this));
            if (wantBal < _wantAmt) {
                _wantAmt = wantBal;
            }
            pool.want.safeTransfer(address(msg.sender), _wantAmt);
        }

        user.rewardDebt = user.shares.mul(pool.accFRXPerShare).div(1e8);

        if (pending > 0) {
            safeFRXTransfer(msg.sender, pending);
        }

        emit Withdraw(msg.sender, _pid, _wantAmt);
    }

    function withdrawAll(uint256 _pid) public nonReentrant {
        withdraw(_pid, uint256(- 1));
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 wantLockedTotal =
        IStrategy(poolInfo[_pid].strat).wantLockedTotal();
        uint256 sharesTotal = IStrategy(poolInfo[_pid].strat).sharesTotal();
        uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);

        IStrategy(poolInfo[_pid].strat).withdraw(msg.sender, amount);

        pool.want.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
        user.shares = 0;
        user.rewardDebt = 0;
    }

    // Safe AUTO transfer function, just in case if rounding error causes pool to not have enough
    function safeFRXTransfer(address _to, uint256 _FRXAmt) internal {
        uint256 FRXBal = IERC20(FRX).balanceOf(address(this));
        if (_FRXAmt > FRXBal) {
            IERC20(FRX).transfer(_to, FRXBal);
        } else {
            IERC20(FRX).transfer(_to, _FRXAmt);
        }
    }

    function inCaseTokensGetStuck(address _token, uint256 _amount) public onlyOwner {
        require(_token != FRX, "!safe");
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }
}
