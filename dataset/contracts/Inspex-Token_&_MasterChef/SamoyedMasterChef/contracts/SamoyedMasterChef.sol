// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./libraries/SafeBEP20.sol";
import "./tokens/KennelClub.sol";
import "./tokens/SamoyToken.sol";

contract SamoyedMasterChef is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of SMOYs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accSmoyPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accSmoyPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. SMOYs to distribute per block.
        uint256 lastRewardBlock; // Last block number that SMOYs distribution occurs.
        uint256 accSmoyPerShare; // Accumulated SMOYs per share, times 1e12. See below.
        uint256 minDepositFeeRate; // Deposit Fee 50 = 0.5%
        uint256 maxDepositFeeRate; // Deposit Fee 200 = 2.0%
        bool enabled; // true = Enabled, false = Disabled
    }

    // The SMOY TOKEN!
    SamoyToken public smoy;
    // The FLAME TOKEN!
    KennelClub public kennel;
    // Dev address.
    address public devAddr;
    // DepositFee wallet keeper
    address public feeCollectorAddr;
    // SMOY tokens created per block.
    uint256 public smoyPerBlock;
    // Bonus muliplier for early smoy makers.
    uint256 public BONUS_MULTIPLIER = 1;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when SMOY mining starts.
    uint256 public startBlock;
    // Minimum smoy to prevent deposit fee
    uint256 public minimumSmoy = 200_000_000_000_000_000_000;
    uint256 public LIMIT_DEPOSIT_FEE_RATE = 10000; // limit fee at 25%

    mapping(address => bool) public isAddedPool;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event SmoyPerBlockUpdated(uint256 smoyPerBlock);
    event MultiplierUpdated(uint256 BONUS_MULTIPLIER);
    event DevAddressUpdated(address dev);
    event FeeCollectorAddressUpdated(address feeCollectorAddr);
    event MinimumSmoyUpdated(uint256 minimumSmoy);
    event PoolAdded(uint256 allocPoint, IBEP20 lpToken, uint256 minDepositFeeRate, uint256 maxDepositFeeRate);
    event PoolUpdated(
        uint256 pid,
        uint256 allocPoint,
        uint256 minDepositFeeRate,
        uint256 maxDepositFeeRate,
        bool enabled
    );

    constructor(
        SamoyToken _smoy,
        KennelClub _kennel,
        address _devAddr,
        address _FeeCollectorAddr,
        uint256 _smoyPerBlock,
        uint256 _startBlock
    ) {
        smoy = _smoy;
        kennel = _kennel;
        devAddr = _devAddr;
        feeCollectorAddr = _FeeCollectorAddr;
        smoyPerBlock = _smoyPerBlock;
        startBlock = _startBlock;

        // staking pool
        poolInfo.push(
            PoolInfo({
                lpToken: _smoy,
                allocPoint: 500,
                lastRewardBlock: startBlock,
                accSmoyPerShare: 0,
                minDepositFeeRate: 0,
                maxDepositFeeRate: 0,
                enabled: true
            })
        );

        totalAllocPoint = 500;
    }

    function updateMultiplier(uint256 multiplierNumber) external onlyOwner {
        massUpdatePools();
        BONUS_MULTIPLIER = multiplierNumber;
        emit MultiplierUpdated(BONUS_MULTIPLIER);
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IBEP20 _lpToken,
        uint256 _minDepositFeeRate,
        uint256 _maxDepositFeeRate
    ) external onlyOwner {
        require(address(_lpToken) != address(0), "SamoyedMasterChef: Can't add address 0");
        require(!isAddedPool[address(_lpToken)], "SamoyedMasterChef: Duplicated LP Token");
        require(_minDepositFeeRate <= _maxDepositFeeRate, "SamoyedMasterChef: Min Fee should Less Than or Equal Max");
        require(_maxDepositFeeRate <= LIMIT_DEPOSIT_FEE_RATE, "SamoyedMasterChef: Fee rate is too high");

        massUpdatePools();
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accSmoyPerShare: 0,
                minDepositFeeRate: _minDepositFeeRate,
                maxDepositFeeRate: _maxDepositFeeRate,
                enabled: true
            })
        );

        isAddedPool[address(_lpToken)] = true;

        emit PoolAdded(_allocPoint, _lpToken, _minDepositFeeRate, _maxDepositFeeRate);
    }

    // Update the given pool's SMOY allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        uint256 _minDepositFeeRate,
        uint256 _maxDepositFeeRate,
        bool _enabled
    ) external onlyOwner {
        require(_minDepositFeeRate <= _maxDepositFeeRate, "SamoyedMasterChef: Min Fee should Less Than or Equal Max");
        require(_maxDepositFeeRate <= LIMIT_DEPOSIT_FEE_RATE, "SamoyedMasterChef: Fee rate is too high");

        massUpdatePools();
        PoolInfo storage pool = poolInfo[_pid];
        uint256 prevAllocPoint = pool.allocPoint;
        pool.allocPoint = _allocPoint;
        pool.minDepositFeeRate = _minDepositFeeRate;
        pool.maxDepositFeeRate = _maxDepositFeeRate;
        pool.enabled = _enabled;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(_allocPoint);
        }

        emit PoolUpdated(_pid, _allocPoint, _minDepositFeeRate, _maxDepositFeeRate, _enabled);
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending SMOYs on frontend.
    function pendingSmoy(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accSmoyPerShare = pool.accSmoyPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 smoyReward = multiplier.mul(smoyPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accSmoyPerShare = accSmoyPerShare.add(smoyReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accSmoyPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            if (poolInfo[pid].enabled) {
                updatePool(pid);
            }
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 smoyReward = multiplier.mul(smoyPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        smoy.mintTo(devAddr, smoyReward.div(10));
        smoy.mintTo(address(kennel), smoyReward);
        pool.accSmoyPerShare = pool.accSmoyPerShare.add(smoyReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for SMOY allocation.
    function deposit(uint256 _pid, uint256 _amount) external nonReentrant {
        require(_pid != 0, "SamoyedMasterChef: deposit SMOY by staking");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accSmoyPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                safeSmoyTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            uint256 currentBal = pool.lpToken.balanceOf(address(this));
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            uint256 receivedAmount = pool.lpToken.balanceOf(address(this)) - currentBal;
            uint256 amountAfterFee = collectDepositFee(_pid, receivedAmount);
            user.amount = user.amount.add(amountAfterFee);
        }
        user.rewardDebt = user.amount.mul(pool.accSmoyPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        require(_pid != 0, "SamoyedMasterChef: withdraw SMOY by unstaking");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "SamoyedMasterChef: withdraw: not good");

        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accSmoyPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            safeSmoyTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accSmoyPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Stake SMOY tokens to MasterChef
    function enterStaking(uint256 _amount) external nonReentrant {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool(0);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accSmoyPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                safeSmoyTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accSmoyPerShare).div(1e12);

        kennel.mint(msg.sender, _amount);
        emit Deposit(msg.sender, 0, _amount);
    }

    // Withdraw SMOY tokens from STAKING.
    function leaveStaking(uint256 _amount) external nonReentrant {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        require(user.amount >= _amount, "SamoyedMasterChef: withdraw: not good");
        updatePool(0);
        uint256 pending = user.amount.mul(pool.accSmoyPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            safeSmoyTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accSmoyPerShare).div(1e12);

        kennel.burn(msg.sender, _amount);
        emit Withdraw(msg.sender, 0, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        if (_pid == 0) {
            kennel.burn(msg.sender, user.amount);
        }
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe smoy transfer function, just in case if rounding error causes pool to not have enough SMOYs.
    function safeSmoyTransfer(address _to, uint256 _amount) private {
        kennel.safeSmoyTransfer(_to, _amount);
    }

    // Collect deposit fee 1.5% if user has less than 200 SMOY
    function collectDepositFee(uint256 _pid, uint256 _amount) private returns (uint256 amount) {
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.minDepositFeeRate > 0 || pool.maxDepositFeeRate > 0) {
            uint256 userBalance = smoy.balanceOf(msg.sender);
            uint256 depositFeeRate = userBalance < minimumSmoy ? pool.maxDepositFeeRate : pool.minDepositFeeRate;

            uint256 fee = _amount.mul(depositFeeRate).div(10000);
            pool.lpToken.transfer(feeCollectorAddr, fee);
            return _amount.sub(fee);
        }

        return _amount;
    }

    // Update dev address by the previous dev.
    function dev(address _devAddr) external {
        require(msg.sender == devAddr, "dev: you are not devAddr.");
        devAddr = _devAddr;
        emit DevAddressUpdated(devAddr);
    }

    // Update deposit feeCollectorAddress
    function updateFeeCollector(address _feeCollectorAddr) external onlyOwner {
        feeCollectorAddr = _feeCollectorAddr;
        emit FeeCollectorAddressUpdated(feeCollectorAddr);
    }

    // Update Minimum Smoy
    function updateMinimumSmoy(uint256 _minimumSmoy) external onlyOwner {
        minimumSmoy = _minimumSmoy;
        emit MinimumSmoyUpdated(minimumSmoy);
    }

    // Update SmoyPerBlock
    function updateSmoyPerBlock(uint256 _smoyPerBlock) external onlyOwner {
        massUpdatePools();
        smoyPerBlock = _smoyPerBlock;
        emit SmoyPerBlockUpdated(smoyPerBlock);
    }
}
