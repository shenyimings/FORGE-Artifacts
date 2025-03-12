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
contract MasterChefETH is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardETHDebt; // Reward debt in ETH.
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
        uint256 allocPoint;       // How many allocation points assigned to this pool. VEMPs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that VEMPs distribution occurs.
        uint256 accVEMPPerShare; // Accumulated VEMPs per share, times 1e12. See below.
        uint256 accETHPerShare; // Accumulated ETHs per share, times 1e12. See below.
        uint256 lastTotalETHReward; // last total rewards
        uint256 lastETHRewardBalance; // last ETH rewards tokens
        uint256 totalETHReward; // total ETH rewards tokens
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
    PoolInfo public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (address => UserInfo) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when VEMP mining starts.
    uint256 public startBlock;
    // total ETH staked
    uint256 public totalETHStaked;
    // total ETH used for purchase land
    uint256 public totalETHUsedForPurchase = 0;

    event Deposit(address indexed user, uint256 amount);

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
        
        updatePool(0);
        
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(100);
        poolInfo.allocPoint = 100;
        poolInfo.lastRewardBlock = lastRewardBlock;
        poolInfo.accVEMPPerShare = 0;
        poolInfo.accETHPerShare = 0;
        poolInfo.lastTotalETHReward = 0;
        poolInfo.lastETHRewardBalance = 0;
        poolInfo.totalETHReward = 0;
    }
    
    //to recieve ETH from admin
    receive() external payable {}

    // Update the given pool's VEMP allocation point. Can only be called by the owner.
    function set( uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            updatePool(0);
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo.allocPoint).add(_allocPoint);
        poolInfo.allocPoint = _allocPoint;
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
    function pendingVEMP(address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[_user];
        uint256 accVEMPPerShare = pool.accVEMPPerShare;
        uint256 lpSupply = totalETHStaked;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 VEMPReward = multiplier.mul(VEMPPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accVEMPPerShare = accVEMPPerShare.add(VEMPReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accVEMPPerShare).div(1e12).sub(user.rewardDebt);
    }
    
    // View function to see pending ETHs on frontend.
    function pendingETH(address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[_user];
        uint256 accETHPerShare = pool.accETHPerShare;
        uint256 lpSupply = totalETHStaked;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 rewardBalance = address(this).balance.sub(totalETHStaked.sub(totalETHUsedForPurchase));
            uint256 _totalReward = rewardBalance.sub(pool.lastETHRewardBalance);
            accETHPerShare = accETHPerShare.add(_totalReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accETHPerShare).div(1e12).sub(user.rewardETHDebt);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _amount) internal {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 rewardBalance = address(this).balance.sub(_amount).sub(totalETHStaked.sub(totalETHUsedForPurchase));
        uint256 _totalReward = pool.totalETHReward.add(rewardBalance.sub(pool.lastETHRewardBalance));
        pool.lastETHRewardBalance = rewardBalance;
        pool.totalETHReward = _totalReward;
        
        uint256 lpSupply = totalETHStaked;
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            pool.accETHPerShare = 0;
            pool.lastTotalETHReward = 0;
            user.rewardETHDebt = 0;
            pool.lastETHRewardBalance = 0;
            pool.totalETHReward = 0;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 VEMPReward = multiplier.mul(VEMPPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        pool.accVEMPPerShare = pool.accVEMPPerShare.add(VEMPReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
        
        uint256 reward = _totalReward.sub(pool.lastTotalETHReward);
        pool.accETHPerShare = pool.accETHPerShare.add(reward.mul(1e12).div(lpSupply));
        pool.lastTotalETHReward = _totalReward;
    }

    // Deposit LP tokens to MasterChef for VEMP allocation.
    function deposit(uint256 _amount) public payable {
        require(msg.value == _amount, "Eth must be equal to staked amount");
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        updatePool(msg.value);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accVEMPPerShare).div(1e12).sub(user.rewardDebt);
            safeVEMPTransfer(msg.sender, pending);
            
            uint256 ETHReward = user.amount.mul(pool.accETHPerShare).div(1e12).sub(user.rewardETHDebt);
            msg.sender.transfer(ETHReward);
            pool.lastETHRewardBalance = address(this).balance.sub(msg.value).sub(totalETHStaked.sub(totalETHUsedForPurchase));
        }
        totalETHStaked = totalETHStaked.add(msg.value);
        user.amount = user.amount.add(msg.value);
        user.rewardDebt = user.amount.mul(pool.accVEMPPerShare).div(1e12);
        user.rewardETHDebt = user.amount.mul(pool.accETHPerShare).div(1e12);
        emit Deposit(msg.sender, msg.value);
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
    
    // Earn ETH tokens to MasterChef.
    function claimETH() public {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        updatePool(0);
        
        uint256 ETHReward = user.amount.mul(pool.accETHPerShare).div(1e12).sub(user.rewardETHDebt);
        msg.sender.transfer(ETHReward);
        pool.lastETHRewardBalance = address(this).balance.sub(totalETHStaked.sub(totalETHUsedForPurchase));
        
        user.rewardETHDebt = user.amount.mul(pool.accETHPerShare).div(1e12);
    }
    
    // Safe ETH transfer function to admin.
    function accessETHTokens(address payable _to, uint256 _amount) public {
        require(msg.sender == adminaddr, "sender must be admin address");
        require(totalETHStaked.sub(totalETHUsedForPurchase) >= _amount, "Amount must be less than staked ETH amount");
        uint256 ETHBal = address(this).balance;
        if (_amount > ETHBal) {
            _to.transfer(ETHBal);
            totalETHUsedForPurchase = totalETHUsedForPurchase.add(ETHBal);
        } else {
            _to.transfer(_amount);
            totalETHUsedForPurchase = totalETHUsedForPurchase.add(_amount);
        }
    }
    
    // Update Reward per block
    function updateRewardPerBlock(uint256 _newRewardPerBlock) public onlyOwner {
        updatePool(0);
        VEMPPerBlock = _newRewardPerBlock;
    }

    // Update admin address by the previous admin.
    function admin(address _adminaddr) public {
        require(msg.sender == adminaddr, "admin: wut?");
        adminaddr = _adminaddr;
    }
}