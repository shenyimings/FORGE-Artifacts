// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./SHEESHA.sol";

contract SHEESHAVault is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of SHEESHAs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accSheeshaPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accSheeshaPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 token; // Address of token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. SHEESHAs to distribute per block.
        uint256 lastRewardBlock; // Last block number that SHEESHAs distribution occurs.
        uint256 accSheeshaPerShare; // Accumulated SHEESHAs per share, times 1e12. See below.
    }

    // The SHEESHA TOKEN!
    SHEESHA public sheesha;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes  tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;

    // The block number when SHEESHA mining starts.
    uint256 public startBlock;

    // SHEESHA tokens percenatge created per block based on rewards pool- 0.01%
    uint256 public constant sheeshaPerBlock = 1;
    //handle case till 0.01(2 decimal places)
    uint256 public constant percentageDivider = 10000;
    //10000 sheesha 10% of supply
    uint256 public tokenRewards = 10000e18;
    

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        SHEESHA _sheesha
    ) {
        sheesha = _sheesha;
        startBlock = block.number;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _token,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                token: _token,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accSheeshaPerShare: 0
            })
        );
    }

    // Update the given pool's SHEESHA allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Update reward vairables for all pools. Be careful of gas spending!
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
        uint256 tokenSupply = pool.token.balanceOf(address(this));
        if (tokenSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 sheeshaReward = (tokenRewards.mul(sheeshaPerBlock).div(percentageDivider)).mul(pool.allocPoint).div(totalAllocPoint);
        tokenRewards = tokenRewards.sub(sheeshaReward);
        pool.accSheeshaPerShare = pool.accSheeshaPerShare.add(sheeshaReward.mul(1e12).div(tokenSupply));
    }

    // Deposit LP tokens to MasterChef for SHEESHA allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accSheeshaPerShare).div(1e12).sub(user.rewardDebt);
            safeSheeshaTransfer(msg.sender, pending);
        }
        //Transfer in the amounts from user
        // save gas
        if(_amount > 0) {
            pool.token.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accSheeshaPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // stake from LGE directly
    // Test coverage
    // [x] Does user get the deposited amounts?
    // [x] Does user that its deposited for update correcty?
    // [x] Does the depositor get their tokens decreased
    function depositFor(address _depositFor, uint256 _pid, uint256 _amount) public {
        // requires no allowances
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_depositFor];

        updatePool(_pid);

        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accSheeshaPerShare).div(1e12).sub(user.rewardDebt);
            safeSheeshaTransfer(_depositFor, pending);
        }

        if(_amount > 0) {
            pool.token.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount); // This is depositedFor address
        }

        user.rewardDebt = user.amount.mul(pool.accSheeshaPerShare).div(1e12); /// This is deposited for address
        emit Deposit(_depositFor, _pid, _amount);
    }

    // Withdraw LP tokens or claim rewards if amount is 0.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accSheeshaPerShare).div(1e12).sub(user.rewardDebt);
        safeSheeshaTransfer(msg.sender, pending);
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            uint256 fees = _amount.mul(4).div(100); //4%
            uint256 burnAmount = fees.mul(1).div(100); //1%
            sheesha.burn(burnAmount);
            //add tax into rewards distribution
            tokenRewards = tokenRewards.add(fees.sub(burnAmount));
            pool.token.safeTransfer(address(msg.sender), _amount.sub(fees.sub(burnAmount)));
        }
        user.rewardDebt = user.amount.mul(pool.accSheeshaPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    //user must approve this contract to add rewards
    function addRewards(uint256 _amount) public onlyOwner {
        require(_amount > 0, "Invalid amount");
        IERC20(sheesha).safeTransferFrom(address(msg.sender), address(this), _amount);
        tokenRewards = tokenRewards.add(_amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.token.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe sheesha transfer function, just in case if rounding error causes pool to not have enough SHEESHAs.
    function safeSheeshaTransfer(address _to, uint256 _amount) internal {
        uint256 sheeshaBal = sheesha.balanceOf(address(this));
        if (_amount > sheeshaBal) {
            sheesha.transfer(_to, sheeshaBal);
        } else {
            sheesha.transfer(_to, _amount);
        }
    }
    
    // View function to see pending SHEESHAs on frontend.
    function pendingSheesha(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accSheeshaPerShare = pool.accSheeshaPerShare;
        uint256 tokenSupply = pool.token.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && tokenSupply != 0) {
            uint256 sheeshaReward = (tokenRewards.mul(sheeshaPerBlock).div(percentageDivider)).mul(pool.allocPoint).div(totalAllocPoint);
            accSheeshaPerShare = accSheeshaPerShare.add(sheeshaReward.mul(1e12).div(tokenSupply));
        }
        return user.amount.mul(accSheeshaPerShare).div(1e12).sub(user.rewardDebt);
    }

}