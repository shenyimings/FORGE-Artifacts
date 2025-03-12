// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../common/Ownable.sol";
import "../interface/IERC20.sol";

// MasterChef is the master of xVEMP. He can make xVEMP and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once xVEMP is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChefBEP20Vemp is Ownable {
    using SafeMath for uint256;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of xVEMPs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accxVEMPPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accxVEMPPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. xVEMPs to distribute per block.
        uint256 lastRewardBlock; // Last block number that xVEMPs distribution occurs.
        uint256 accxVEMPPerShare; // Accumulated xVEMPs per share, times 1e12. See below.
    }

    // The xVEMP TOKEN!
    IERC20 public xVEMP;
    // admin address.
    address public adminaddr;
    // Block number when bonus SUSHI period ends.
    uint256 public bonusEndBlock;
    // xVEMP tokens created per block.
    uint256 public xVEMPPerBlock;
    // Bonus muliplier for early xVEMP makers.
    uint256 public constant BONUS_MULTIPLIER = 1;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when xVEMP mining starts.
    uint256 public startBlock;
    // Total VEMP Staked
    uint256 public totalVempStaked;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor() public {}

    function initialize(
        IERC20 _xVEMP,
        address _adminaddr,
        uint256 _xVEMPPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) public initializer {
        Ownable.init(_adminaddr);
        xVEMP = _xVEMP;
        adminaddr = _adminaddr;
        xVEMPPerBlock = _xVEMPPerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accxVEMPPerShare: 0
            })
        );
    }

    // Update the given pool's xVEMP allocation point. Can only be called by the owner.
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
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return
                bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                    _to.sub(bonusEndBlock)
                );
        }
    }

    // View function to see pending xVEMPs on frontend.
    function pendingxVEMP(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accxVEMPPerShare = pool.accxVEMPPerShare;
        uint256 PoolEndBlock = block.number;
        if (block.number > bonusEndBlock) {
            PoolEndBlock = bonusEndBlock;
        }
        uint256 lpSupply = totalVempStaked;
        if (PoolEndBlock > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                PoolEndBlock
            );
            uint256 xVEMPReward = multiplier
                .mul(xVEMPPerBlock)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            accxVEMPPerShare = accxVEMPPerShare.add(
                xVEMPReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accxVEMPPerShare).div(1e12).sub(user.rewardDebt);
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
        uint256 lpSupply = totalVempStaked;
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 PoolEndBlock = block.number;
        if (block.number > bonusEndBlock) {
            PoolEndBlock = bonusEndBlock;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, PoolEndBlock);
        uint256 xVEMPReward = multiplier
            .mul(xVEMPPerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);
        pool.accxVEMPPerShare = pool.accxVEMPPerShare.add(
            xVEMPReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = PoolEndBlock;
    }

    // Deposit LP tokens to MasterChef for xVEMP allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user
                .amount
                .mul(pool.accxVEMPPerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            safeVEMPTransfer(_pid, address(msg.sender), pending);
        }
        pool.lpToken.transferFrom(address(msg.sender), address(this), _amount);
        xVEMP.mint(address(msg.sender), _amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accxVEMPPerShare).div(1e12);
        totalVempStaked = totalVempStaked.add(_amount);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accxVEMPPerShare).div(1e12).sub(
            user.rewardDebt
        );
        safeVEMPTransfer(_pid, address(msg.sender), pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accxVEMPPerShare).div(1e12);
        totalVempStaked = totalVempStaked.sub(_amount);
        xVEMP.burnFrom(address(msg.sender), _amount);
        pool.lpToken.transfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        xVEMP.burnFrom(address(msg.sender), user.amount);
        pool.lpToken.transfer(address(msg.sender), user.amount);
        totalVempStaked = totalVempStaked.sub(user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    }

    // Safe MANA transfer function to admin.
    function emergencyWithdrawRewardTokens(
        uint256 _pid,
        address _to,
        uint256 _amount
    ) public {
        require(msg.sender == adminaddr, "sender must be admin address");
        PoolInfo storage pool = poolInfo[_pid];
        uint256 vempBal = pool.lpToken.balanceOf(address(this));
        require(
            vempBal.sub(totalVempStaked) > _amount,
            "Insufficiently reward amount"
        );
        safeVEMPTransfer(_pid, _to, _amount);
    }

    // Safe VEMP transfer function, just in case if rounding error causes pool to not have enough xVEMPs.
    function safeVEMPTransfer(
        uint256 _pid,
        address _to,
        uint256 _amount
    ) internal {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 VEMPBal = pool.lpToken.balanceOf(address(this)).sub(
            totalVempStaked
        );
        if (_amount > VEMPBal) {
            pool.lpToken.transfer(_to, VEMPBal);
        } else {
            pool.lpToken.transfer(_to, _amount);
        }
    }

    // Update Reward per block
    function updateRewardPerBlock(uint256 _newRewardPerBlock) public onlyOwner {
        massUpdatePools();
        xVEMPPerBlock = _newRewardPerBlock;
    }

    // Update End block
    function updateEndBlock(uint256 _bonusEndBlock) public onlyOwner {
        massUpdatePools();
        bonusEndBlock = _bonusEndBlock;
    }

    // Update admin address by the previous admin.
    function admin(address _adminaddr) public {
        require(msg.sender == adminaddr, "admin: wut?");
        adminaddr = _adminaddr;
    }
}