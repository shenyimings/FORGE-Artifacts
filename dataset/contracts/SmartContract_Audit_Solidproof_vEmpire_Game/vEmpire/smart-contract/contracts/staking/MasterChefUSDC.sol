// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../common/Ownable.sol";

// MasterChef is the master of VEMP. He can make VEMP and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once VEMP is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChefUSDC is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardUSDCDebt; // Reward debt in USDC.
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
        uint256 accUSDCPerShare; // Accumulated USDCs per share, times 1e12. See below.
        uint256 lastTotalUSDCReward; // last total rewards
        uint256 lastUSDCRewardBalance; // last USDC rewards tokens
        uint256 totalUSDCReward; // total USDC rewards tokens
    }

    // The VEMP TOKEN!
    IERC20 public VEMP;
    // admin address.
    address public adminaddr;
    // VEMP tokens created per block.
    uint256 public VEMPPerBlock;
    // Bonus muliplier for early VEMP makers.
    uint256 public BONUS_MULTIPLIER;

    // Info of each pool.
    PoolInfo public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (address => UserInfo) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when VEMP mining starts.
    uint256 public startBlock;
    // total USDC staked
    uint256 public totalUSDCStaked;
    // total USDC used for purchase land
    uint256 public totalUSDCUsedForPurchase = 0;
    // withdraw status
    bool public withdrawStatus;
    // reward end status
    bool public rewardEndStatus;
    // reward end block number
    uint256 public rewardEndBlock;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event RewardEndStatus(bool rewardStatus, uint256 rewardEndBlock);
    event RewardPerBlock(uint256 oldRewardPerBlock, uint256 newRewardPerBlock);
    event AccessUSDCToken(address indexed user, uint256 amount, uint256 totalUSDCUsedForPurchase);
    event AddUSDCTokensInPool(uint256 amount, uint256 totalUSDCUsedForPurchase);

    constructor() public {}

    function initialize(
        IERC20 _VEMP,
        IERC20 _lpToken,
        address _adminaddr,
        uint256 _VEMPPerBlock,
        uint256 _startBlock
    ) public initializer {
        require(address(_VEMP) != address(0), "Invalid VEMP address");
        require(address(_lpToken) != address(0), "Invalid lpToken address");
        require(address(_adminaddr) != address(0), "Invalid admin address");
        Ownable.init(_adminaddr);
        VEMP = _VEMP;
        adminaddr = _adminaddr;
        VEMPPerBlock = _VEMPPerBlock;
        startBlock = _startBlock;
        withdrawStatus = false;
        rewardEndStatus = false;
        rewardEndBlock = 0;
        BONUS_MULTIPLIER = 1;
        
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(100);
        poolInfo.lpToken = _lpToken;
        poolInfo.allocPoint = 100;
        poolInfo.lastRewardBlock = lastRewardBlock;
        poolInfo.accVEMPPerShare = 0;
        poolInfo.accUSDCPerShare = 0;
        poolInfo.lastTotalUSDCReward = 0;
        poolInfo.lastUSDCRewardBalance = 0;
        poolInfo.totalUSDCReward = 0;
    }
    
    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
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
        uint256 rewardBlockNumber = block.number;
        if(rewardEndStatus != false) {
           rewardBlockNumber = rewardEndBlock;
        }
        uint256 lpSupply = totalUSDCStaked;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, rewardBlockNumber);
            uint256 VEMPReward = multiplier.mul(VEMPPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accVEMPPerShare = accVEMPPerShare.add(VEMPReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accVEMPPerShare).div(1e12).sub(user.rewardDebt);
    }
    
    // View function to see pending USDCs on frontend.
    function pendingUSDC(address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[_user];
        uint256 accUSDCPerShare = pool.accUSDCPerShare;
        uint256 lpSupply = totalUSDCStaked;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 rewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalUSDCStaked.sub(totalUSDCUsedForPurchase));
            uint256 _totalReward = rewardBalance.sub(pool.lastUSDCRewardBalance);
            accUSDCPerShare = accUSDCPerShare.add(_totalReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accUSDCPerShare).div(1e12).sub(user.rewardUSDCDebt);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool() internal {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 rewardBlockNumber = block.number;
        if(rewardEndStatus != false) {
           rewardBlockNumber = rewardEndBlock;
        }
        uint256 rewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalUSDCStaked.sub(totalUSDCUsedForPurchase));
        uint256 _totalReward = pool.totalUSDCReward.add(rewardBalance.sub(pool.lastUSDCRewardBalance));
        pool.lastUSDCRewardBalance = rewardBalance;
        pool.totalUSDCReward = _totalReward;
        
        uint256 lpSupply = totalUSDCStaked;
        if (lpSupply == 0) {
            pool.lastRewardBlock = rewardBlockNumber;
            pool.accUSDCPerShare = 0;
            pool.lastTotalUSDCReward = 0;
            user.rewardUSDCDebt = 0;
            pool.lastUSDCRewardBalance = 0;
            pool.totalUSDCReward = 0;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, rewardBlockNumber);
        uint256 VEMPReward = multiplier.mul(VEMPPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        pool.accVEMPPerShare = pool.accVEMPPerShare.add(VEMPReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = rewardBlockNumber;
        
        uint256 reward = _totalReward.sub(pool.lastTotalUSDCReward);
        pool.accUSDCPerShare = pool.accUSDCPerShare.add(reward.mul(1e12).div(lpSupply));
        pool.lastTotalUSDCReward = _totalReward;
    }

    // Deposit LP tokens to MasterChef for VEMP allocation.
    function deposit(uint256 _amount) public {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        updatePool();
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accVEMPPerShare).div(1e12).sub(user.rewardDebt);
            safeVEMPTransfer(msg.sender, pending);
            
            uint256 USDCReward = user.amount.mul(pool.accUSDCPerShare).div(1e12).sub(user.rewardUSDCDebt);
            pool.lpToken.safeTransfer(msg.sender, USDCReward);
            pool.lastUSDCRewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalUSDCStaked.sub(totalUSDCUsedForPurchase));
        }
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        totalUSDCStaked = totalUSDCStaked.add(_amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accVEMPPerShare).div(1e12);
        user.rewardUSDCDebt = user.amount.mul(pool.accUSDCPerShare).div(1e12);
        emit Deposit(msg.sender, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _amount) public {
        require(withdrawStatus != true, "Withdraw not allowed");
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool();
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accVEMPPerShare).div(1e12).sub(user.rewardDebt);
            safeVEMPTransfer(msg.sender, pending);
            
            uint256 USDCReward = user.amount.mul(pool.accUSDCPerShare).div(1e12).sub(user.rewardUSDCDebt);
            pool.lpToken.safeTransfer(msg.sender, USDCReward);
            pool.lastUSDCRewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalUSDCStaked.sub(totalUSDCUsedForPurchase));
        }
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accVEMPPerShare).div(1e12);
        user.rewardUSDCDebt = user.amount.mul(pool.accUSDCPerShare).div(1e12);
        totalUSDCStaked = totalUSDCStaked.sub(_amount);
        pool.lpToken.safeTransfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {
        require(withdrawStatus != true, "Withdraw not allowed");
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        pool.lpToken.safeTransfer(msg.sender, user.amount);
        totalUSDCStaked = totalUSDCStaked.sub(user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
        user.rewardUSDCDebt = 0;
        emit EmergencyWithdraw(msg.sender, user.amount);
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
    
    // Earn USDC tokens to MasterChef.
    function claimUSDC() public {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        updatePool();
        
        uint256 USDCReward = user.amount.mul(pool.accUSDCPerShare).div(1e12).sub(user.rewardUSDCDebt);
        pool.lpToken.safeTransfer(msg.sender, USDCReward);
        pool.lastUSDCRewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalUSDCStaked.sub(totalUSDCUsedForPurchase));
        
        user.rewardUSDCDebt = user.amount.mul(pool.accUSDCPerShare).div(1e12);
    }
    
    // Safe USDC transfer function to admin.
    function accessUSDCTokens(address _to, uint256 _amount) public {
        require(_to != address(0), "Invalid to address");
        require(msg.sender == adminaddr, "sender must be admin address");
        require(totalUSDCStaked.sub(totalUSDCUsedForPurchase) >= _amount, "Amount must be less than staked USDC amount");
        PoolInfo storage pool = poolInfo;
        uint256 USDCBal = pool.lpToken.balanceOf(address(this));
        if (_amount > USDCBal) {
            pool.lpToken.safeTransfer(_to, USDCBal);
            totalUSDCUsedForPurchase = totalUSDCUsedForPurchase.add(USDCBal);
        } else {
            pool.lpToken.safeTransfer(_to, _amount);
            totalUSDCUsedForPurchase = totalUSDCUsedForPurchase.add(_amount);
        }
        emit AccessUSDCToken(_to, _amount, totalUSDCUsedForPurchase);
    }

    // Safe add USDC in pool
     function addUSDCTokensInPool(uint256 _amount) public {
        require(_amount > 0, "USDC amount must be greater than 0");
        require(msg.sender == adminaddr, "sender must be admin address");
        require(_amount.add(totalUSDCStaked.sub(totalUSDCUsedForPurchase)) <= totalUSDCStaked, "Amount must be less than staked USDC amount");
        PoolInfo storage pool = poolInfo;
        totalUSDCUsedForPurchase = totalUSDCUsedForPurchase.sub(_amount);
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        emit AddUSDCTokensInPool(_amount, totalUSDCUsedForPurchase);
    }

    // Update Reward per block
    function updateRewardPerBlock(uint256 _newRewardPerBlock) public onlyOwner {
        updatePool();
        emit RewardPerBlock(VEMPPerBlock, _newRewardPerBlock);
        VEMPPerBlock = _newRewardPerBlock;
    }

    // Update withdraw status
    function updateWithdrawStatus(bool _status) public onlyOwner {
        require(withdrawStatus != _status, "Already same status");
        withdrawStatus = _status;
    }

    // Update reward end status
    function updateRewardEndStatus(bool _status, uint256 _rewardEndBlock) public onlyOwner {
        require(rewardEndStatus != _status, "Already same status");
        require(_rewardEndBlock >= block.number, "Invalid Reward End Block");
        rewardEndBlock = _rewardEndBlock;
        rewardEndStatus = _status;
        emit RewardEndStatus(_status, _rewardEndBlock);
    }

    // Update admin address by the previous admin.
    function admin(address _adminaddr) public {
        require(_adminaddr != address(0), "Invalid admin address");
        require(msg.sender == adminaddr, "admin: wut?");
        adminaddr = _adminaddr;
    }

    // Safe VEMP transfer function to admin.
    function emergencyWithdrawRewardTokens(address _to, uint256 _amount) public {
        require(_to != address(0), "Invalid to address");
        require(msg.sender == adminaddr, "sender must be admin address");
        safeVEMPTransfer(_to, _amount);
    }
}
