// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IBasePool.sol";
import "./base/TokenSaver.sol";

contract LiquidityMiningManager is TokenSaver {

    bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");
    bytes32 public constant REWARD_DISTRIBUTOR_ROLE = keccak256("REWARD_DISTRIBUTOR_ROLE");

    IERC20 immutable public reward;
    address immutable public rewardSource;
    uint256 public rewardPerSecond; //total reward amount per second
    uint256 public lastDistribution; //when rewards were last pushed
    uint256 public totalWeight;

    mapping(address => bool) public poolAdded;
    Pool[] public pools;

    struct Pool {
        IBasePool poolContract;
        uint256 weight;
    }

    modifier onlyGov {
        require(hasRole(GOV_ROLE, _msgSender()), "LiquidityMiningManager.onlyGov: permission denied");
        _;
    }

    modifier onlyRewardDistributor {
        require(hasRole(REWARD_DISTRIBUTOR_ROLE, _msgSender()), "LiquidityMiningManager.onlyRewardDistributor: permission denied");
        _;
    }

    event PoolAdded(address indexed pool, uint256 weight);
    event PoolRemoved(uint256 indexed poolId, address indexed pool);
    event WeightAdjusted(uint256 indexed poolId, address indexed pool, uint256 newWeight);
    event RewardsPerSecondSet(uint256 rewardsPerSecond);
    event RewardsDistributed(address _from, uint256 indexed _amount);

    constructor(address _reward, address _rewardSource) {
        reward = IERC20(_reward);
        rewardSource = _rewardSource;
    }

    function addPool(address _poolContract, uint256 _weight) external onlyGov {
        distributeRewards();
        require(!poolAdded[_poolContract], "LiquidityMiningManager.addPool: Pool already added");
        // add pool
        pools.push(Pool({
            poolContract: IBasePool(_poolContract),
            weight: _weight
        }));
        poolAdded[_poolContract] = true;
        
        // increase totalWeight
        totalWeight += _weight;

        // Approve max token amount
        reward.approve(_poolContract, type(uint256).max);

        emit PoolAdded(_poolContract, _weight);
    }

    function removePool(uint256 _poolId) external onlyGov {
        distributeRewards();
        address poolAddress = address(pools[_poolId].poolContract);

        // decrease totalWeight
        totalWeight -= pools[_poolId].weight;
        
        // remove pool
        pools[_poolId] = pools[pools.length - 1];
        pools.pop();
        poolAdded[poolAddress] = false;

        emit PoolRemoved(_poolId, poolAddress);
    }

    function adjustWeight(uint256 _poolId, uint256 _newWeight) external onlyGov {
        distributeRewards();
        Pool storage pool = pools[_poolId];

        totalWeight -= pool.weight;
        totalWeight += _newWeight;

        pool.weight = _newWeight;

        emit WeightAdjusted(_poolId, address(pool.poolContract), _newWeight);
    }

    function setRewardPerSecond(uint256 _rewardPerSecond) external onlyGov {
        distributeRewards();
        rewardPerSecond = _rewardPerSecond;

        emit RewardsPerSecondSet(_rewardPerSecond);
    }

    function distributeRewards() public onlyRewardDistributor {
        uint256 timePassed = block.timestamp - lastDistribution;
        uint256 totalRewardAmount = rewardPerSecond * timePassed;
        lastDistribution = block.timestamp;

        // return if pool length == 0
        if(pools.length == 0) {
            return;
        }

        // return if accrued rewards == 0
        if(totalRewardAmount == 0) {
            return;
        }

        reward.transferFrom(rewardSource, address(this), totalRewardAmount);

        for(uint256 i = 0; i < pools.length; i ++) {
            Pool memory pool = pools[i];
            uint256 poolRewardAmount = totalRewardAmount * pool.weight / totalWeight;
            // ignore tx failing
            address(pool.poolContract).call(abi.encodeWithSelector(pool.poolContract.distributeRewards.selector, poolRewardAmount));
        }

        uint256 leftOverReward = reward.balanceOf(address(this));

        // send back excess but ignore dust
        if(leftOverReward > 1) {
            reward.transfer(rewardSource, leftOverReward);
        }

        emit RewardsDistributed(_msgSender(), totalRewardAmount);
    }

    function getPools() external view returns(Pool[] memory result) {
        return pools;
    }
}