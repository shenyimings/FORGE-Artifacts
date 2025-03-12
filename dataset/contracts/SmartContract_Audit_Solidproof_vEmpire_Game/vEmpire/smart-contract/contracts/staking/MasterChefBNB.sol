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
contract MasterChefBNB is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardBNBDebt; // Reward debt in BNB.
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
        uint256 accBNBPerShare; // Accumulated BNBs per share, times 1e12. See below.
        uint256 lastTotalBNBReward; // last total rewards
        uint256 lastBNBRewardBalance; // last BNB rewards tokens
        uint256 totalBNBReward; // total BNB rewards tokens
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
    // total BNB staked
    uint256 public totalBNBStaked;
    // total BNB used for purchase land
    uint256 public totalBNBUsedForPurchase = 0;
    // withdraw status
    bool public withdrawStatus;
    // reward end status
    bool public rewardEndStatus;
    // rewad end block number
    uint256 public rewardEndBlock;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor() public {}

    function initialize(
        IERC20 _VEMP,
        address _adminaddr,
        uint256 _VEMPPerBlock,
        uint256 _startBlock
    ) public initializer {
        Ownable.init(_adminaddr);
        VEMP = _VEMP;
        adminaddr = _adminaddr;
        VEMPPerBlock = _VEMPPerBlock;
        startBlock = _startBlock;
        withdrawStatus = false;
        rewardEndStatus = false;
        rewardEndBlock = 0;
        
        updatePool(0);
        
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(100);
        poolInfo.allocPoint = 100;
        poolInfo.lastRewardBlock = lastRewardBlock;
        poolInfo.accVEMPPerShare = 0;
        poolInfo.accBNBPerShare = 0;
        poolInfo.lastTotalBNBReward = 0;
        poolInfo.lastBNBRewardBalance = 0;
        poolInfo.totalBNBReward = 0;
    }
    
    //to recieve BNB from admin
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
        uint256 rewardBlockNumber = block.number;
        if(rewardEndStatus != false) {
           rewardBlockNumber = rewardEndBlock;
        }
        uint256 lpSupply = totalBNBStaked;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, rewardBlockNumber);
            uint256 VEMPReward = multiplier.mul(VEMPPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accVEMPPerShare = accVEMPPerShare.add(VEMPReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accVEMPPerShare).div(1e12).sub(user.rewardDebt);
    }
    
    // View function to see pending BNBs on frontend.
    function pendingBNB(address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[_user];
        uint256 accBNBPerShare = pool.accBNBPerShare;
        uint256 lpSupply = totalBNBStaked;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 rewardBalance = address(this).balance.sub(totalBNBStaked.sub(totalBNBUsedForPurchase));
            uint256 _totalReward = rewardBalance.sub(pool.lastBNBRewardBalance);
            accBNBPerShare = accBNBPerShare.add(_totalReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accBNBPerShare).div(1e12).sub(user.rewardBNBDebt);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _amount) internal {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 rewardBlockNumber = block.number;
        if(rewardEndStatus != false) {
           rewardBlockNumber = rewardEndBlock;
        }
        uint256 rewardBalance = address(this).balance.sub(_amount).sub(totalBNBStaked.sub(totalBNBUsedForPurchase));
        uint256 _totalReward = pool.totalBNBReward.add(rewardBalance.sub(pool.lastBNBRewardBalance));
        pool.lastBNBRewardBalance = rewardBalance;
        pool.totalBNBReward = _totalReward;
        
        uint256 lpSupply = totalBNBStaked;
        if (lpSupply == 0) {
            pool.lastRewardBlock = rewardBlockNumber;
            pool.accBNBPerShare = 0;
            pool.lastTotalBNBReward = 0;
            user.rewardBNBDebt = 0;
            pool.lastBNBRewardBalance = 0;
            pool.totalBNBReward = 0;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, rewardBlockNumber);
        uint256 VEMPReward = multiplier.mul(VEMPPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        pool.accVEMPPerShare = pool.accVEMPPerShare.add(VEMPReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = rewardBlockNumber;
        
        uint256 reward = _totalReward.sub(pool.lastTotalBNBReward);
        pool.accBNBPerShare = pool.accBNBPerShare.add(reward.mul(1e12).div(lpSupply));
        pool.lastTotalBNBReward = _totalReward;
    }

    // Deposit LP tokens to MasterChef for VEMP allocation.
    function deposit(uint256 _amount) public payable {
        require(msg.value == _amount, "BNB must be equal to staked amount");
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        updatePool(msg.value);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accVEMPPerShare).div(1e12).sub(user.rewardDebt);
            safeVEMPTransfer(msg.sender, pending);
            
            uint256 BNBReward = user.amount.mul(pool.accBNBPerShare).div(1e12).sub(user.rewardBNBDebt);
            msg.sender.transfer(BNBReward);
            pool.lastBNBRewardBalance = address(this).balance.sub(msg.value).sub(totalBNBStaked.sub(totalBNBUsedForPurchase));
        }
        totalBNBStaked = totalBNBStaked.add(msg.value);
        user.amount = user.amount.add(msg.value);
        user.rewardDebt = user.amount.mul(pool.accVEMPPerShare).div(1e12);
        user.rewardBNBDebt = user.amount.mul(pool.accBNBPerShare).div(1e12);
        emit Deposit(msg.sender, msg.value);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _amount) public {
        require(withdrawStatus != false, "Withdraw not allowed");
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(0);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accVEMPPerShare).div(1e12).sub(user.rewardDebt);
            safeVEMPTransfer(msg.sender, pending);
            
            uint256 BNBReward = user.amount.mul(pool.accBNBPerShare).div(1e12).sub(user.rewardBNBDebt);
            msg.sender.transfer(BNBReward);
            pool.lastBNBRewardBalance = address(this).balance.sub(0).sub(totalBNBStaked.sub(totalBNBUsedForPurchase));
        }
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accVEMPPerShare).div(1e12);
        user.rewardBNBDebt = user.amount.mul(pool.accBNBPerShare).div(1e12);
        totalBNBStaked = totalBNBStaked.sub(_amount);
        msg.sender.transfer(_amount);
        emit Withdraw(msg.sender, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {
        require(withdrawStatus != false, "Withdraw not allowed");
        UserInfo storage user = userInfo[msg.sender];
        msg.sender.transfer(user.amount);
        totalBNBStaked = totalBNBStaked.sub(user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
        user.rewardBNBDebt = 0;
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
    
    // Earn BNB tokens to MasterChef.
    function claimBNB() public {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        updatePool(0);
        
        uint256 BNBReward = user.amount.mul(pool.accBNBPerShare).div(1e12).sub(user.rewardBNBDebt);
        msg.sender.transfer(BNBReward);
        pool.lastBNBRewardBalance = address(this).balance.sub(totalBNBStaked.sub(totalBNBUsedForPurchase));
        
        user.rewardBNBDebt = user.amount.mul(pool.accBNBPerShare).div(1e12);
    }
    
    // Safe BNB transfer function to admin.
    function accessBNBTokens(address payable _to, uint256 _amount) public {
        require(msg.sender == adminaddr, "sender must be admin address");
        require(totalBNBStaked.sub(totalBNBUsedForPurchase) >= _amount, "Amount must be less than staked BNB amount");
        uint256 BNBBal = address(this).balance;
        if (_amount > BNBBal) {
            _to.transfer(BNBBal);
            totalBNBUsedForPurchase = totalBNBUsedForPurchase.add(BNBBal);
        } else {
            _to.transfer(_amount);
            totalBNBUsedForPurchase = totalBNBUsedForPurchase.add(_amount);
        }
    }

    // Safe add BNB in pool
     function addBNBTokensInPool(uint256 _amount) public  payable {
        require(msg.value == _amount, "BNB must be equal to staked amount");
        require(msg.sender == adminaddr, "sender must be admin address");
        require(_amount.add(totalBNBStaked.sub(totalBNBUsedForPurchase)) <= totalBNBStaked, "Amount must be less than staked BNB amount");
        totalBNBUsedForPurchase = totalBNBUsedForPurchase.sub(_amount);
    }

    // Update Reward per block
    function updateRewardPerBlock(uint256 _newRewardPerBlock) public onlyOwner {
        updatePool(0);
        VEMPPerBlock = _newRewardPerBlock;
    }

    // Update withdraw status
    function updateWithdrawStatus(bool _status) public onlyOwner {
        require(withdrawStatus != _status, "Already same status");
        withdrawStatus = _status;
    }

    // Update reward end status
    function updateRewardEndStatus(bool _status) public onlyOwner {
        require(rewardEndStatus != _status, "Already same status");
        rewardEndBlock = block.number;
        rewardEndStatus = _status;
    }

    // Update admin address by the previous admin.
    function admin(address _adminaddr) public {
        require(msg.sender == adminaddr, "admin: wut?");
        adminaddr = _adminaddr;
    }

    // Safe VEMP transfer function to admin.
    function emergencyWithdrawRewardTokens(address _to, uint256 _amount) public {
        require(msg.sender == adminaddr, "sender must be admin address");
        safeVEMPTransfer(_to, _amount);
    }
}