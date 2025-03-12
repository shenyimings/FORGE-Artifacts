pragma solidity =0.6.12;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

// MasterChef is the master of VEMP. He can make VEMP and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once VEMP is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChefSAND is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardSANDDebt; // Reward debt in SAND.
        //
        // We do some fancy math here. Basically, any point in time, the amount of VEMPs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accVEMPPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accVEMPPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. VEMPs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that VEMPs distribution occurs.
        uint256 accVEMPPerShare; // Accumulated VEMPs per share, times 1e12. See below.
        uint256 accSANDPerShare; // Accumulated SANDs per share, times 1e12. See below.
        uint256 lastTotalSANDReward; // last total rewards
        uint256 lastSANDRewardBalance; // last SAND rewards tokens
        uint256 totalSANDReward; // total SAND rewards tokens
    }

    // The VEMP TOKEN!
    IERC20 public VEMP;
    // admin address.
    address public adminaddr;
    // VEMP tokens created per block.
    uint256 public VEMPPerBlock;
    // Bonus muliplier for early VEMP makers.
    uint256 public constant BONUS_MULTIPLIER = 1;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when VEMP mining starts.
    uint256 public startBlock;
    // total SAND staked
    uint256 public totalSANDStaked;
    // total SAND used for purchase land
    uint256 public totalSANDUsedForPurchase = 0;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        IERC20 _VEMP,
        address _adminaddr,
        uint256 _VEMPPerBlock,
        uint256 _startBlock
    ) public {
        VEMP = _VEMP;
        adminaddr = _adminaddr;
        VEMPPerBlock = _VEMPPerBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accVEMPPerShare: 0,
            accSANDPerShare: 0,
            lastTotalSANDReward: 0,
            lastSANDRewardBalance: 0,
            totalSANDReward: 0
        }));
    }

    // Update the given pool's VEMP allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }
    
    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        if (_to >= _from) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else {
            return _from.sub(_to);
        }
    }

    // View function to see pending VEMPs on frontend.
    function pendingVEMP(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accVEMPPerShare = pool.accVEMPPerShare;
        uint256 lpSupply = totalSANDStaked;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 VEMPReward = multiplier.mul(VEMPPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accVEMPPerShare = accVEMPPerShare.add(VEMPReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accVEMPPerShare).div(1e12).sub(user.rewardDebt);
    }
    
    // View function to see pending SANDs on frontend.
    function pendingSAND(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accSANDPerShare = pool.accSANDPerShare;
        uint256 lpSupply = totalSANDStaked;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 rewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalSANDStaked.sub(totalSANDUsedForPurchase));
            uint256 _totalReward = rewardBalance.sub(pool.lastSANDRewardBalance);
            accSANDPerShare = accSANDPerShare.add(_totalReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accSANDPerShare).div(1e12).sub(user.rewardSANDDebt);
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
        UserInfo storage user = userInfo[_pid][msg.sender];
        
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 rewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalSANDStaked.sub(totalSANDUsedForPurchase));
        uint256 _totalReward = pool.totalSANDReward.add(rewardBalance.sub(pool.lastSANDRewardBalance));
        pool.lastSANDRewardBalance = rewardBalance;
        pool.totalSANDReward = _totalReward;
        
        uint256 lpSupply = totalSANDStaked;
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            pool.accSANDPerShare = 0;
            pool.lastTotalSANDReward = 0;
            user.rewardSANDDebt = 0;
            pool.lastSANDRewardBalance = 0;
            pool.totalSANDReward = 0;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 VEMPReward = multiplier.mul(VEMPPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        pool.accVEMPPerShare = pool.accVEMPPerShare.add(VEMPReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
        
        uint256 reward = _totalReward.sub(pool.lastTotalSANDReward);
        pool.accSANDPerShare = pool.accSANDPerShare.add(reward.mul(1e12).div(lpSupply));
        pool.lastTotalSANDReward = _totalReward;
    }

    // Deposit LP tokens to MasterChef for VEMP allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accVEMPPerShare).div(1e12).sub(user.rewardDebt);
            safeVEMPTransfer(msg.sender, pending);
            
            uint256 SANDReward = user.amount.mul(pool.accSANDPerShare).div(1e12).sub(user.rewardSANDDebt);
            pool.lpToken.safeTransfer(msg.sender, SANDReward);
            pool.lastSANDRewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalSANDStaked.sub(totalSANDUsedForPurchase));
        }
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        totalSANDStaked = totalSANDStaked.add(_amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accVEMPPerShare).div(1e12);
        user.rewardSANDDebt = user.amount.mul(pool.accSANDPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }
    
    // Earn SAND tokens to MasterChef.
    function claimSAND(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        
        uint256 SANDReward = user.amount.mul(pool.accSANDPerShare).div(1e12).sub(user.rewardSANDDebt);
        pool.lpToken.safeTransfer(msg.sender, SANDReward);
        pool.lastSANDRewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalSANDStaked.sub(totalSANDUsedForPurchase));
        
        user.rewardSANDDebt = user.amount.mul(pool.accSANDPerShare).div(1e12);
    }

    // Safe VEMP transfer function, just in case if rounding error causes pool to not have enough VEMPs.
    function safeVEMPTransfer(address _to, uint256 _amount) internal {
        uint256 VEMPBal = VEMP.balanceOf(address(this));
        if (_amount > VEMPBal) {
            VEMP.transfer(_to, VEMPBal);
        } else {
            VEMP.transfer(_to, _amount);
        }
    }
    
    // Safe SAND transfer function to admin.
    function accessSANDTokens(uint256 _pid, address _to, uint256 _amount) public {
        require(msg.sender == adminaddr, "sender must be admin address");
        require(totalSANDStaked.sub(totalSANDUsedForPurchase) >= _amount, "Amount must be less than staked SAND amount");
        PoolInfo storage pool = poolInfo[_pid];
        uint256 SANDBal = pool.lpToken.balanceOf(address(this));
        if (_amount > SANDBal) {
            pool.lpToken.transfer(_to, SANDBal);
            totalSANDUsedForPurchase = totalSANDUsedForPurchase.add(SANDBal);
        } else {
            pool.lpToken.transfer(_to, _amount);
            totalSANDUsedForPurchase = totalSANDUsedForPurchase.add(_amount);
        }
    }
    
    // Update Reward per block
    function updateRewardPerBlock(uint256 _newRewardPerBlock) public onlyOwner {
        massUpdatePools();
        VEMPPerBlock = _newRewardPerBlock;
    }

    // Update admin address by the previous admin.
    function admin(address _adminaddr) public {
        require(msg.sender == adminaddr, "admin: wut?");
        adminaddr = _adminaddr;
    }
}