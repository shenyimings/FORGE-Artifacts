// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.6.6;

import './interfaces/IERC20.sol';
import './interfaces/IEchodexFactory.sol';
import "./libraries/TransferHelper.sol";
import "./libraries/SafeMath.sol";

contract EchodexFarm {
    using SafeMath  for uint;

    address public immutable owner;
    address public immutable factory;
    address public immutable WETH;

    uint256 public currentPoolId;

    struct PoolInfo {
        uint256 poolId;
        address pairAddress;
        uint256 amountReward;
        address tokenReward;
        uint256 startDate;  // second timestamp
        uint256 endDate;    // second timestamp
        uint256 realEndDate;  // second timestamp
        address owner;
    }

    struct PoolReward {
        uint256 accAmountPerShare;
        uint256 totalLP;
        uint256 totalReward;
        uint256 amountPerSecond;
        uint256 lastRewardTimestamp;
        uint256 totalExcessReward;
        uint256 startTimeExcess;
    }
    mapping (uint256 => PoolInfo) public poolInfos;
    mapping (uint256 => PoolReward) public poolRewards;

    struct User {
        uint256 amount;
        uint256 rewardDebt;
        uint256 rewardEarn;
    }
    mapping(address => mapping(uint256 => User)) public users; // address => poolId => UserInfo

    event PoolCreated(
        uint256 poolId,
        address indexed pairAddress,
        address tokenA,
        address tokenB,
        uint256 amountReward,
        address indexed tokenReward,
        uint256 startDate,
        uint256 endDate,
        uint256 amountPerSecond
    );

    event PoolUpdate(
        uint256 indexed poolId,
        uint256 accAmountPerShare,
        uint256 totalLP,
        uint256 totalReward,
        uint256 lastRewardTimestamp
    );

    event UserUpdate(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount,
        uint256 rewardDebt,
        uint256 rewardEarn
    );

    event Stake(
        uint256 indexed poolId,
        address indexed user,
        uint256 amount
    );

    event Unstake(
        uint256 indexed poolId,
        address indexed user,
        uint256 amount
    );

    event Harvest(
        uint256 indexed poolId,
        address indexed user,
        uint256 amountHarvested
    );

    event WithdrawExcess(
        uint256 indexed poolId,
        uint256 amount
    );

    event BlueCheck(
        uint256 indexed poolId,
        bool isBlueCheck
    );

    event StopPool(
        uint256 indexed poolId
    );

    constructor(address _factory, address _WETH) public {
        owner = msg.sender;
        factory = _factory;
        WETH = _WETH;
    }

    function createPool(address tokenA, address tokenB, uint256 amountReward, address tokenReward, uint256 startDate, uint256 endDate) payable external {
        require(block.timestamp <= startDate, "EchodexFarm: WRONG_TIME");
        require(startDate + 30 * 60 <= endDate, "EchodexFarm: WRONG_TIME");
        require(amountReward > 0, "EchodexFarm: AMOUNT_NOT_VALID");
        address pairAddress = IEchodexFactory(factory).getPair(tokenA, tokenB);
        require(pairAddress != address(0), "EchodexFarm: PAIR_NOT_EXIST");
        require(tokenReward != address(0), "EchodexFarm: TOKEN_REWARD_NOT_VALID");

        if (tokenReward == WETH) {
            require(msg.value == amountReward, "EchodexFarm: AMOUNT_NOT_VALID");
        } else {
            TransferHelper.safeTransferFrom(tokenReward, msg.sender, address(this), amountReward);
        }
        uint256 amountPerSecond = amountReward.div(endDate.sub(startDate));
        poolInfos[currentPoolId] = PoolInfo({
            poolId: currentPoolId,
            pairAddress: pairAddress,
            amountReward: amountReward,
            tokenReward: tokenReward,
            startDate: startDate,
            endDate: endDate,
            realEndDate: endDate,
            owner: msg.sender
        });

        poolRewards[currentPoolId] = PoolReward({
            accAmountPerShare: 0,
            totalLP: 0,
            totalReward: 0,
            amountPerSecond: amountPerSecond,
            lastRewardTimestamp: 0,
            startTimeExcess: startDate,
            totalExcessReward: 0
        });
       
        emit PoolCreated(currentPoolId, pairAddress, tokenA, tokenB, amountReward, tokenReward, startDate, endDate, amountPerSecond);

        currentPoolId++;
    }
  
    function stake(uint256 poolId, uint256 amountLP) external {
        require(amountLP > 0 , "EchodexFarm: AMOUNT_LP_NOT_ZERO");

        PoolInfo storage poolInfo = poolInfos[poolId];
        require(poolInfo.startDate <= block.timestamp, "EchodexFarm: NOT_START");
        require(block.timestamp <= poolInfo.endDate, "EchodexFarm: OVER_TIME");
        require(amountLP <= IERC20(poolInfo.pairAddress).balanceOf(msg.sender), "EchodexFarm: BALANCE_NOT_ENOUGH");

        PoolReward storage poolReward = poolRewards[poolId];
        if (poolReward.totalLP == 0) {
            poolReward.lastRewardTimestamp = block.timestamp;
        }

        if (poolReward.startTimeExcess != 0) {
            poolReward.totalExcessReward = poolReward.totalExcessReward.add(block.timestamp.sub(poolReward.startTimeExcess));
            poolReward.startTimeExcess = 0;
        }

        User storage user = users[msg.sender][poolId];

        _update(poolInfo, poolReward);
        _audit(user, poolReward);

        TransferHelper.safeTransferFrom(poolInfo.pairAddress, msg.sender, address(this), amountLP);
        poolReward.totalLP = poolReward.totalLP.add(amountLP);
        user.amount = user.amount.add(amountLP);
        user.rewardDebt = user.amount.mul(poolReward.accAmountPerShare).div(1e12);

        emit PoolUpdate(poolId, poolReward.accAmountPerShare, poolReward.totalLP, poolReward.totalReward, poolReward.lastRewardTimestamp);
        emit UserUpdate(msg.sender, poolId, user.amount, user.rewardDebt, user.rewardEarn);
        emit Stake(poolId, msg.sender, amountLP);
    }

    function unstake(uint256 poolId, uint256 amountLP) external {
        require(amountLP > 0 , "EchodexFarm: AMOUNT_LP_NOT_ZERO");

        PoolInfo storage poolInfo = poolInfos[poolId];
        PoolReward storage poolReward = poolRewards[poolId];
        User storage user = users[msg.sender][poolId];
        require(amountLP <= user.amount , "EchodexFarm: INSUFFICIENT_AMOUNT");

        _update(poolInfo, poolReward);
        _audit(user, poolReward);

        TransferHelper.safeTransfer(poolInfo.pairAddress, msg.sender, amountLP);

        poolReward.totalLP = poolReward.totalLP.sub(amountLP);
        user.amount = user.amount.sub(amountLP);
        user.rewardDebt = user.amount.mul(poolReward.accAmountPerShare).div(1e12);

        if (poolReward.totalLP == 0 && block.timestamp < poolInfo.endDate) {
            poolReward.startTimeExcess = block.timestamp;
        }

        emit PoolUpdate(poolId, poolReward.accAmountPerShare, poolReward.totalLP, poolReward.totalReward, poolReward.lastRewardTimestamp);
        emit UserUpdate(msg.sender, poolId, user.amount, user.rewardDebt, user.rewardEarn);
        emit Unstake(poolId, msg.sender, amountLP);
    }

    function harvest(uint256 poolId) external {
        PoolInfo storage poolInfo = poolInfos[poolId];
        PoolReward storage poolReward = poolRewards[poolId];
        User storage user = users[msg.sender][poolId];

        _update(poolInfo, poolReward);
        _audit(user, poolReward);

        require(user.rewardEarn > 0, "EchodexFarm: NO_REWARD");

        // set user rewardEarn to 0 before transfer to prevent reentrancy attack
        uint rewardEarn = user.rewardEarn;
        user.rewardEarn = 0;

        if (poolInfo.tokenReward == WETH) {
            TransferHelper.safeTransferETH(msg.sender, rewardEarn);
        } else {
            TransferHelper.safeTransfer(poolInfo.tokenReward, msg.sender, rewardEarn);
        }
        emit Harvest(poolId, msg.sender, rewardEarn);
        emit UserUpdate(msg.sender, poolId, user.amount, user.rewardDebt, rewardEarn);
    }

    function withdrawExcessReward(uint256 poolId) external {
        PoolInfo storage poolInfo = poolInfos[poolId];
        PoolReward storage poolReward = poolRewards[poolId];
        require(poolInfo.owner == msg.sender, "EchodexFarm: NO_PERMISSION");
        require(poolInfo.endDate < block.timestamp, "EchodexFarm: POOL_NOT_END");

        if (poolReward.startTimeExcess != 0) {
            poolReward.totalExcessReward = poolReward.totalExcessReward.add(poolInfo.realEndDate.sub(poolReward.startTimeExcess));
            poolReward.startTimeExcess = 0;
        }

        require(poolReward.totalExcessReward > 0, "EchodexFarm: NO_EXCESS");

        // set user rewardEarn to 0 before transfer to prevent reentrancy attack
        uint totalExcessReward = poolReward.totalExcessReward;
        poolReward.totalExcessReward = 0;

        if (poolInfo.tokenReward == WETH) {
            TransferHelper.safeTransferETH(msg.sender, totalExcessReward.mul(poolReward.amountPerSecond));
        } else {
            TransferHelper.safeTransfer(poolInfo.tokenReward, msg.sender, totalExcessReward.mul(poolReward.amountPerSecond));
        }

        emit WithdrawExcess(poolId, totalExcessReward);
    }

    function setBlueCheck(uint256 poolId, bool isBlueCheck) external {
        require(owner == msg.sender, "EchodexFarm: FORBIDDEN");
        require(poolId < currentPoolId, "EchodexFarm: NOT_EXIST");

        emit BlueCheck(poolId, isBlueCheck);
    }

    function stopPool(uint256 poolId) external {
        PoolInfo storage poolInfo = poolInfos[poolId];
        PoolReward storage poolReward = poolRewards[poolId];
        require(poolInfo.owner == msg.sender, "EchodexFarm: NO_PERMISSION");

        if (poolReward.startTimeExcess != 0) {
            poolReward.totalExcessReward = poolReward.totalExcessReward.add(poolInfo.endDate.sub(poolReward.startTimeExcess));
            poolReward.startTimeExcess = 0;
        } else {
            poolReward.totalExcessReward = poolReward.totalExcessReward.add(poolInfo.endDate.sub(block.timestamp));
        }

        poolInfo.endDate = block.timestamp;

        emit StopPool(poolId);
    }

    function _update(PoolInfo storage poolInfo, PoolReward storage poolReward) private {
        if (poolReward.totalLP > 0 && poolReward.lastRewardTimestamp <= poolInfo.endDate) {
            uint256 currentReward = block.timestamp.sub(poolReward.lastRewardTimestamp).mul(poolReward.amountPerSecond);
            if (block.timestamp > poolInfo.endDate) {
                currentReward = poolInfo.endDate.sub(poolReward.lastRewardTimestamp).mul(poolReward.amountPerSecond);
                poolReward.lastRewardTimestamp = poolInfo.endDate;
            } else {
                poolReward.lastRewardTimestamp = block.timestamp;
            }
            poolReward.accAmountPerShare = poolReward.accAmountPerShare.add(currentReward.mul(1e12).div(poolReward.totalLP));
            poolReward.totalReward = poolReward.totalReward.add(currentReward);
        }
    }

    function _audit(User storage user, PoolReward storage poolReward) private {
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(poolReward.accAmountPerShare).div(1e12).sub(user.rewardDebt);
            user.rewardEarn = user.rewardEarn.add(pending);
            user.rewardDebt = user.amount.mul(poolReward.accAmountPerShare).div(1e12);
        }
    }
}