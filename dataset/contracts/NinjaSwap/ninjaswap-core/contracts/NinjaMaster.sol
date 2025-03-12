pragma solidity 0.6.12;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./NinjaToken.sol";

contract NinjaMaster is Ownable {
    uint256 public constant period1 = 180 days; // about 6 months
    uint256 public constant period2 = 365 days; // 1 year
    uint256 public constant period3 = 730 days;  // 2 years
    uint256 public constant period4 = 1460 days; // 4 years  
    uint256 public Reward = 200000 * 1e18;
    uint256 public periodFinish = 0;
    uint256 Period1Status=0;
    uint256 Period2Status=0;
    uint256 Period3Status=0;
    uint256 Period4Status=0;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public rewardRate = 0;

    // Info of each user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardPerTokenPaid;
        uint256 rewards;
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;
        uint256 allocPoint;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    // The NINJA TOKEN!
    NinjaToken public ninja;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // add the same LP token only once
    mapping(address => bool) lpExists;

    event RewardAdded(uint256 reward);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(NinjaToken _ninja) public {
        ninja = _ninja;
    }
    modifier reduceHalve() {
        if (periodFinish == 0) {
            periodFinish = block.timestamp.add(period1);
            rewardRate = Reward.div(period1);
            ninja.mint(address(this), Reward);
            emit RewardAdded(Reward);
            Period1Status = 1;
         } 
         if(block.timestamp >= periodFinish && Period2Status == 0) {
            periodFinish = block.timestamp.add(period2);
            rewardRate = Reward.div(period2);
            ninja.mint(address(this), Reward);
            emit RewardAdded(Reward);
            Period2Status = 1;
        } 
        if(block.timestamp >= periodFinish && Period3Status == 0) {
            periodFinish = block.timestamp.add(period3);
            rewardRate = Reward.div(period3);
            ninja.mint(address(this), Reward);
            emit RewardAdded(Reward);
            Period3Status = 1;
        }   
        if(block.timestamp >= periodFinish && Period4Status == 0) {
            periodFinish = block.timestamp.add(period4);
            // calcualte 4th reward as AMO added 0.1x in wallet 
            uint256 masterChefWallet = ninja.masterChefWallet();
            // add 800k in wallet and minus 3 previous rewards
            uint256 reward4th = masterChefWallet.add(800000000000000000000000).sub(Reward.mul(3));
            rewardRate = reward4th.div(period3);
            ninja.mint(address(this), reward4th);
            emit RewardAdded(reward4th);
            Period4Status = 1;
        }      
        _;
    }

 

    modifier updateReward(uint256 _pid, address _user) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        pool.rewardPerTokenStored = rewardPerToken(_pid);
        pool.lastUpdateTime = lastTimeRewardApplicable();
        if (_user != address(0)) {
            user.rewards = earned(_pid, _user);
            user.rewardPerTokenPaid = pool.rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return (periodFinish == 0 || block.timestamp < periodFinish) ? block.timestamp : periodFinish;
    }

    function rewardPerToken(uint256 _pid) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            return pool.rewardPerTokenStored;
        }
        return pool.rewardPerTokenStored.add(
            lastTimeRewardApplicable()
            .sub(pool.lastUpdateTime == 0 ? block.timestamp : pool.lastUpdateTime)
            .mul(rewardRate)
            .mul(pool.allocPoint)
            .div(totalAllocPoint)
            .mul(1e18)
            .div(lpSupply)
        );
    }

    function earned(uint256 _pid, address _user) public view returns (uint256) {
        UserInfo storage user = userInfo[_pid][_user];
        return user.amount
        .mul(rewardPerToken(_pid).sub(user.rewardPerTokenPaid))
        .div(1e18)
        .add(user.rewards);
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IERC20 _lpToken) public onlyOwner {
        require(!lpExists[address(_lpToken)], "do not add the same lp token more than once");

        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken : _lpToken,
            allocPoint : _allocPoint,
            lastUpdateTime : 0,
            rewardPerTokenStored : 0
            }));

        lpExists[address(_lpToken)] = true;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Update the given pool's NINJA allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint) public onlyOwner {
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // View function to see pending NINJAs on frontend.
    function pendingNINJA(uint256 _pid, address _user) external view returns (uint256) {
        return earned(_pid, _user);
    }

    function _getReward(uint256 _pid, address _user) private {
        UserInfo storage user = userInfo[_pid][_user];
        uint256 reward = earned(_pid, _user);
        if (reward > 0) {
            user.rewards = 0;
            uint256 ninjaBal = ninja.balanceOf(address(this));
            if (reward > ninjaBal) {
                reward = ninjaBal;
            }
            ninja.transfer(_user, reward);
            emit RewardPaid(_user, reward);
        }
    }

    // Deposit LP tokens to MasterChef for NINJA allocation.
    function deposit(uint256 _pid, uint256 _amount) public updateReward(_pid, msg.sender) reduceHalve {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        _getReward(_pid, msg.sender);
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        user.amount = user.amount.add(_amount);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public updateReward(_pid, msg.sender) reduceHalve {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        _getReward(_pid, msg.sender);
        user.amount = user.amount.sub(_amount);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // withdraw reward only.
    function withdrawReward(uint256 _pid) public updateReward(_pid, msg.sender) reduceHalve {
        _getReward(_pid, msg.sender);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewards = 0;
    }

}