// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./AprWarCoin.sol";
import "./IBonusProxy.sol";

pragma solidity ^0.8.0;

contract MasterChef is Ownable {
    using SafeERC20 for IERC20;

    struct PoolInfo {
        IERC20 stakeToken;
        uint factor;
        bool noFees;
        // state vars
        uint totalStake;
        uint totalPower;
        uint rewardPerPower;
        uint rewardUpdateBlock;
        // computable vars
        uint allocPoint;
    }

    struct PoolState {
        uint totalStake;
        uint totalPower;
        uint allocPoint;
        uint stakeFeeBP;
    }

    struct UserInfo {
        uint stake;
        uint referralStake;
        uint power;
        uint reward;
        uint rewardEntrypoint;
        bool restakeBonus;
        mapping(address => bool) referralAccepted;
    }

    struct UserState {
        uint stake;
        uint power;
        uint referralStake;
        bool restakeBonus;
        uint pendingReward;
    }

    uint public startBlock = 0;
    uint public awcPerBlock = 5e17;
    uint public totalAllocPoint = 0;
    uint public restaked = 0;

    AprWarCoin public awc;
    IBonusProxy public proxy;
    address public devAddress;
    address public feeAddress;

    uint constant public feeBase = 10000;
    uint constant public minStakeFeeBP = 100;
    uint constant public maxStakeFeeBP = 400;

    PoolInfo[] public pools;
    mapping(uint => mapping(address => UserInfo)) public users;
    mapping(address => address) public referrers;
    mapping(address => uint) public referrals;

    event Stake(address user, uint poolId, uint amount);
    event Unstake(address user, uint poolId, uint amount);
    event Restake(address user, uint poolId, uint amount);
    event EmergencyWithdraw(address user, uint poolId, uint amount);

    constructor(AprWarCoin _awc, address dev, address fee, uint _startBlock) {
        awc = _awc;
        devAddress = dev;
        feeAddress = fee;
        startBlock = _startBlock;

        // zero pool
        add(_awc, 20, true);
    }

    // ADMIN FUNCTIONS

    function add(IERC20 stakeToken, uint factor, bool noFees) public onlyOwner {
        pools.push(PoolInfo({
            stakeToken: stakeToken,
            factor: factor,
            noFees: noFees,
            totalStake: 0,
            totalPower: 0,
            rewardPerPower: 0,
            rewardUpdateBlock: 0,
            allocPoint: 1
        }));
        totalAllocPoint += 1;
    }

    function set(uint poolId, uint factor) external onlyOwner {
        PoolInfo storage pool = pools[poolId];
        if (pool.factor != factor) {
            uint currentAllocPoint = pool.factor * pool.totalStake + 1;
            pool.factor = factor;
            pool.allocPoint = pool.factor * pool.totalStake + 1;
            totalAllocPoint = totalAllocPoint - currentAllocPoint + pool.allocPoint;
        }
    }

    function setAwcPerBlock(uint _awcPerBlock) external onlyOwner {
        awcPerBlock = _awcPerBlock;
    }

    function setFeeAddress(address fee) external onlyOwner {
        feeAddress = fee;
    }

    function setDevAddress(address dev) external onlyOwner {
        devAddress = dev;
    }

    function setProxy(IBonusProxy _proxy) external onlyOwner {
        proxy = _proxy;
    }

    // ------------------
    // INTERNAL FUNCTIONS

    function poolReward(uint poolId) public view returns (uint) {
        PoolInfo storage pool = pools[poolId];

        if (block.number < startBlock) {
            return 0;
        }

        if (pool.rewardUpdateBlock == 0 || pool.totalPower == 0 || pool.allocPoint == 0 || block.number < pool.rewardUpdateBlock) {
            return 0;
        }

        return (block.number - pool.rewardUpdateBlock) * awcPerBlock * pool.allocPoint / totalAllocPoint;
    }

    function updatePoolReward(uint poolId) private {
        PoolInfo storage pool = pools[poolId];

        uint reward = poolReward(poolId);

        if (reward > 0) {
            awc.mint(devAddress, reward / 25);
            awc.mint(address(this), reward);

            pool.rewardPerPower += reward * 1e12 / pool.totalPower;
        }

        pool.rewardUpdateBlock = block.number;
    }

    function updatePoolParams(uint poolId, uint newTotalStake) private {
        PoolInfo storage pool = pools[poolId];

        uint currentAllocPoint = pool.factor * pool.totalStake + 1;
        pool.totalStake = newTotalStake;
        pool.allocPoint = pool.factor * newTotalStake + 1;
        totalAllocPoint = totalAllocPoint - currentAllocPoint + pool.allocPoint;
    }

    function poolStakeFeeBP(uint poolId) private view returns (uint) {
        PoolInfo storage pool = pools[poolId];

        if (pool.noFees) {
            return 0;
        }
        if (totalAllocPoint == 0) {
            return maxStakeFeeBP;
        }

        uint poolTrueShare = totalAllocPoint / pools.length;
        uint stakeFeeBP = uint(uint(maxStakeFeeBP) * pool.allocPoint / poolTrueShare);
        return Math.max(Math.min(stakeFeeBP, maxStakeFeeBP), minStakeFeeBP);
    }

    function prepareHarvest(uint poolId, address to) private returns (uint) {
        PoolInfo storage pool = pools[poolId];
        UserInfo storage user = users[poolId][to];

        if (user.stake == 0) {
            return 0;
        }

        user.reward += user.power * pool.rewardPerPower / 1e12 - user.rewardEntrypoint;

        return user.reward;
    }

    function updatePower(uint poolId, address to) private {
        PoolInfo storage pool = pools[poolId];
        UserInfo storage user = users[poolId][to];

        if (user.stake == 0) {
            if (user.power > 0) {
                pool.totalPower -= user.power;
                user.power = 0;
            }
            return;
        }

        uint powerBonus = 100;

        address referrer = referrers[to];
        if (referrer != address(0) && users[poolId][referrer].stake > 0) {
            powerBonus += 5;
        }
        if (user.referralStake > 0) {
            uint referalBonus = user.referralStake * 45e12 / (user.stake * 5) / 1e12;
            powerBonus += Math.min(referalBonus, 45);
        }

        if (poolId == 0 && user.restakeBonus) {
            powerBonus += 10;
        }

        if (address(proxy) != address(0)) {
            uint proxyBonus = proxy.bonus(to);
            if (proxyBonus > 0) {
                powerBonus += proxyBonus;
            }
        }

        uint currentPower = user.power;
        user.power = user.stake * powerBonus / 100;
        pool.totalPower = pool.totalPower - currentPower + user.power;
    }

    function updateRewardEntrypoint(uint poolId, address to) private {
        PoolInfo storage pool = pools[poolId];
        UserInfo storage user = users[poolId][to];

        user.rewardEntrypoint = user.power * pool.rewardPerPower / 1e12;
    }

    function harvest(uint poolId) private {
        UserInfo storage user = users[poolId][msg.sender];

        if (user.stake == 0) {
            return;
        }

        uint reward = prepareHarvest(poolId, msg.sender);
        if (reward > awc.balanceOf(address(this))) {
            reward = awc.balanceOf(address(this));
        }
        awc.transfer(msg.sender, reward);
        user.reward = 0;
    }

    function updateReferrer(uint poolId, uint oldStake, uint newStake) private {
        address refAddress = referrers[msg.sender];
        if (refAddress != address(0)) {
            UserInfo storage referrer = users[poolId][refAddress];

            if (!referrer.referralAccepted[msg.sender]) {
                referrer.referralStake += newStake;
                referrer.referralAccepted[msg.sender] = true;
            } else {
                referrer.referralStake = referrer.referralStake - oldStake + newStake;
            }

            prepareHarvest(poolId, refAddress);
            updatePower(poolId, refAddress);
            updateRewardEntrypoint(poolId, refAddress);
        }
    }

    // ------------------
    // PUBLIC FUNCTIONS

    function stake(uint poolId, uint amount) external {
        require(poolId >= 0 && poolId < pools.length, "unknown pool");

        PoolInfo storage pool = pools[poolId];
        UserInfo storage user = users[poolId][msg.sender];

        updatePoolReward(poolId);
        harvest(poolId);

        if (amount > 0) {
            pool.stakeToken.safeTransferFrom(msg.sender, address(this), amount);

            uint depositFee = 0;
            if (!pool.noFees) {
                depositFee = amount * poolStakeFeeBP(poolId) / feeBase;
                pool.stakeToken.safeTransfer(feeAddress, depositFee);
            }

            uint oldStake = user.stake;
            uint stakeAmount = amount - depositFee;
            user.stake += stakeAmount;

            updatePoolParams(poolId, pool.totalStake + stakeAmount);
            updatePower(poolId, msg.sender);
            updateReferrer(poolId, oldStake, user.stake);
        }

        updateRewardEntrypoint(poolId, msg.sender);
        emit Stake(msg.sender, poolId, amount);
    }

    function unstake(uint poolId, uint amount) external {
        require(poolId >= 0 && poolId < pools.length, "unknown pool");

        PoolInfo storage pool = pools[poolId];
        UserInfo storage user = users[poolId][msg.sender];

        updatePoolReward(poolId);
        harvest(poolId);

        if (amount > 0) {
            require(amount <= user.stake, "you can not unstake more than you stake");

            pool.stakeToken.safeTransfer(msg.sender, amount);

            uint oldStake = user.stake;
            user.stake -= amount;

            if (poolId == 0) {
                user.restakeBonus = false;
            }

            updatePoolParams(poolId, pool.totalStake - amount);
            updatePower(poolId, msg.sender);
            updateReferrer(poolId, oldStake, user.stake);
        }

        updateRewardEntrypoint(poolId, msg.sender);
        emit Unstake(msg.sender, poolId, amount);
    }

    function restake(uint poolId) external {
        require(poolId >= 0 && poolId < pools.length, "unknown pool");

        PoolInfo storage zeroPool = pools[0];
        UserInfo storage zeroUser = users[0][msg.sender];
        UserInfo storage fromUser = users[poolId][msg.sender];

        updatePoolReward(poolId);
        prepareHarvest(poolId, msg.sender);
        uint restakeAmount = fromUser.reward;

        if (restakeAmount <= 0) {
            return;
        }

        if (poolId != 0) {
            updatePoolReward(0);
            prepareHarvest(0, msg.sender);
        }

        uint oldStake = zeroUser.stake;
        fromUser.reward = 0;
        zeroUser.restakeBonus = true;
        zeroUser.stake += restakeAmount;
        restaked += restakeAmount;
        updatePoolParams(0, zeroPool.totalStake + restakeAmount);
        updatePower(0, msg.sender);
        updateReferrer(0, oldStake, zeroUser.stake);

        updateRewardEntrypoint(poolId, msg.sender);
        if (poolId != 0) {
            updateRewardEntrypoint(0, msg.sender);
        }
        emit Restake(msg.sender, poolId, restakeAmount);
    }

    function setReferrer(address referrer) external {
        require(referrers[msg.sender] == address(0), "you can set referrer only once");
        require(referrer != msg.sender, "you can not set self as referrer");
        referrers[msg.sender] = referrer;
        referrals[referrer]++;
    }

    function emergencyWithdraw(uint poolId) public {
        PoolInfo storage pool = pools[poolId];
        UserInfo storage user = users[poolId][msg.sender];

        pool.totalPower -= user.power;
        uint amount = user.stake;
        user.power = 0;
        user.stake = 0;
        user.reward = 0;
        user.rewardEntrypoint = 0;

        pool.stakeToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, poolId, amount);
    }

    // ------------------
    // VIEW FUNCTIONS

    function getPoolsState() external view returns (PoolState[] memory) {
        PoolState[] memory state = new PoolState[](pools.length);

        for (uint i = 0; i < pools.length; i++) {
            state[i] = PoolState(
                pools[i].totalStake,
                pools[i].totalPower,
                pools[i].allocPoint,
                poolStakeFeeBP(i)
            );
        }

        return state;
    }

    function getUserState(address to) external view returns (UserState[] memory) {
        UserState[] memory state = new UserState[](pools.length);

        for (uint i = 0; i < pools.length; i++) {
            PoolInfo storage pool = pools[i];
            UserInfo storage user = users[i][to];

            uint rewardPerPower = pool.rewardPerPower;
            if (pool.totalPower > 0) {
                rewardPerPower += poolReward(i) * 1e12 / pool.totalPower;
            }
            uint pengingReward = user.power * rewardPerPower / 1e12 - user.rewardEntrypoint;

            state[i] = UserState(
                user.stake,
                user.power,
                user.referralStake,
                user.restakeBonus,
                pengingReward
            );
        }

        return state;
    }
}
