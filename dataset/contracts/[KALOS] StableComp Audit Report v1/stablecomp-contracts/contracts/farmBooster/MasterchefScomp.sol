// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interface/IERC20.sol";
import "../interface/IVotingEscrow.sol";

contract MasterChefScomp is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;


    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` Used to calculate the correct amount of rewards. See explanation below.
    ///
    /// We do some fancy math here. Basically, any point in time, the amount of TOKENs
    /// entitled to a user but is pending to be distributed is:
    ///
    ///   pending reward = (user share * pool.accTokenPerShare) - user.rewardDebt
    ///
    ///   Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
    ///   1. The pool's `accTokenPerShare` (and `lastRewardBlock`) gets updated.
    ///   2. User receives the pending reward sent to his/her address.
    ///   3. User's `amount` gets updated. Pool's `totalBoostedShare` gets updated.
    ///   4. User's `rewardDebt` gets updated.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 boostMultiplier;
    }

    /// @notice Info of each MCV2 pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    ///     Also known as the amount of "multipliers". Combined with `totalXAllocPoint`, it defines the % of
    ///     TOKEN rewards each pool gets.
    /// `accTokenPerShare` Accumulated TOKENs per share, times 1e12.
    /// `lastRewardBlock` Last block number that pool update action is executed.
    ///     In MasterChef V2 farms are "regular pools". "special pools", which use a different sets of
    ///     `allocPoint` and their own `totalSpecialAllocPoint` are designed to handle the distribution of
    ///     the TOKEN rewards to all the PancakeSwap products.
    /// `totalBoostedShare` The total amount of user shares in each pool. After considering the share boosts.
    struct PoolInfo {
        uint256 accTokenPerShare;
        uint256 lastRewardBlock;
        uint256 allocPoint;
        uint256 totalBoostedShare;
    }

    /// @notice Address of TOKEN contract.
    IERC20 public immutable TOKEN;

    /// @notice Info of each MCV2 pool.
    PoolInfo[] public poolInfo;
    /// @notice Address of the LP token for each MCV2 pool.
    IERC20[] public lpToken;

    /// @notice Info of each pool user.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    /// @notice The whitelist of addresses allowed to deposit in special pools.
    mapping(address => bool) public whiteList;

    /// @notice Total regular allocation points. Must be the sum of all regular pools' allocation points.
    uint256 public totalAllocPoint;

    ///  @notice Amount tokens per block
    uint256 public tokenPerBlock;
    uint256 public constant ACC_TOKEN_PRECISION = 1e18;

    /// @notice Basic boost factor, none boosted user's boost factor
    uint256 public constant BOOST_PRECISION = 100 * 1e10;
    /// @notice Hard limit for maxmium boost factor, it must greater than BOOST_PRECISION
    uint256 public constant MAX_BOOST_PRECISION = 200 * 1e10;

    uint maxMultiplier = 8;

    IVotingEscrow public veContract;

    // The block number when farming starts.
    uint256 public startBlock;
    // The block number when farming ends.
    uint256 public endBlock;


    event Init();
    event AddPool(uint256 indexed pid, uint256 allocPoint, IERC20 indexed lpToken);
    event SetPool(uint256 indexed pid, uint256 allocPoint);
    event UpdatePool(uint256 indexed pid, uint256 lastRewardBlock, uint256 lpSupply, uint256 accTokenPerShare);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    event UpdateBoostMultiplier(address indexed user, uint256 pid, uint256 oldMultiplier, uint256 newMultiplier);

    /// @param _TOKEN The TOKEN token contract address.
    /// @param _veContract The address of voting power contract.
    constructor(
        IERC20 _TOKEN,
        address _veContract,
        uint _tokenPerBlock,
        uint _startBlock
    ) public {
        TOKEN = _TOKEN;
        veContract = IVotingEscrow(_veContract);
        tokenPerBlock = _tokenPerBlock * 1e18;
        startBlock = _startBlock;
        endBlock = _startBlock;

    }

    /// @notice Returns the number of MCV2 pools.
    function poolLength() public view returns (uint256 pools) {
        pools = poolInfo.length;
    }


    // Fund the farm, increase the end block
    function fund(uint256 _amount) public {
        require(block.number < endBlock, "fund: too late, the farm is closed");

        TOKEN.safeTransferFrom(address(msg.sender), address(this), _amount);
        endBlock += _amount.div(tokenPerBlock);
    }

    /// @notice Add a new pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param _allocPoint Number of allocation points for the new pool.
    /// @param _lpToken Address of the LP BEP-20 token.
    /// @param _withUpdate Whether call "massUpdatePools" operation.
    /// only for TOKEN distributions within PancakeSwap products.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) external onlyOwner {
        // stake TOKEN token will cause staked token and reward token mixed up,
        // may cause staked tokens withdraw as reward token,never do it.
        require(_lpToken != TOKEN, "TOKEN token can't be added to farm pools");

        if (_withUpdate) {
            massUpdatePools();
        }

        totalAllocPoint = totalAllocPoint.add(_allocPoint);

        lpToken.push(_lpToken);

        uint256 lastRewardBlock = block.number > startBlock
        ? block.number
        : startBlock;

        poolInfo.push(
            PoolInfo({
        allocPoint: _allocPoint,
        lastRewardBlock: lastRewardBlock,
        accTokenPerShare: 0,
        totalBoostedShare: 0
        })
        );
        emit AddPool(lpToken.length.sub(1), _allocPoint, _lpToken);
    }

    /// @notice Update the given pool's TOKEN allocation point. Can only be called by the owner.
    /// @param _pid The id of the pool. See `poolInfo`.
    /// @param _allocPoint New number of allocation points for the pool.
    /// @param _withUpdate Whether call "massUpdatePools" operation.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) external onlyOwner {
        // No matter _withUpdate is true or false, we need to execute updatePool once before set the pool parameters.
        updatePool(_pid);

        if (_withUpdate) {
            massUpdatePools();
        }

        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);

        poolInfo[_pid].allocPoint = _allocPoint;
        emit SetPool(_pid, _allocPoint);
    }

    /// @notice View function for checking pending TOKEN rewards.
    /// @param _pid The id of the pool. See `poolInfo`.
    /// @param _user Address of the user.
    function pendingToken(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = pool.totalBoostedShare;
        uint256 lastBlock = block.number < endBlock ? block.number : endBlock;

        if (lastBlock > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = lastBlock.sub(pool.lastRewardBlock);

            uint256 tokenReward = multiplier.mul(tokenPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accTokenPerShare = accTokenPerShare.add(tokenReward.mul(ACC_TOKEN_PRECISION).div(lpSupply));
        }

        uint256 boostedAmount = user.amount.mul(getBoostMultiplier(_user, _pid)).div(BOOST_PRECISION);
        return boostedAmount.mul(accTokenPerShare).div(ACC_TOKEN_PRECISION).sub(user.rewardDebt);
    }

    /// @notice Update token reward for all the active pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo memory pool = poolInfo[pid];
            if (pool.allocPoint != 0) {
                updatePool(pid);
            }
        }
    }

    /// @notice Update reward variables for the given pool.
    /// @param _pid The id of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint256 _pid) public returns (PoolInfo memory pool) {
        pool = poolInfo[_pid];
        uint256 lastBlock = block.number < endBlock ? block.number : endBlock;

        if (lastBlock > pool.lastRewardBlock) {
            uint256 lpSupply = pool.totalBoostedShare;

            if (lpSupply > 0 && totalAllocPoint > 0) {
                uint256 multiplier = block.number.sub(pool.lastRewardBlock);
                uint256 tokenReward = multiplier.mul(tokenPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
                pool.accTokenPerShare = pool.accTokenPerShare.add((tokenReward.mul(ACC_TOKEN_PRECISION).div(lpSupply)));
            }
            pool.lastRewardBlock = block.number;
            poolInfo[_pid] = pool;
            emit UpdatePool(_pid, pool.lastRewardBlock, lpSupply, pool.accTokenPerShare);
        }
    }

    /// @notice Deposit LP tokens to pool.
    /// @param _pid The id of the pool. See `poolInfo`.
    /// @param _amount Amount of LP tokens to deposit.
    function deposit(uint256 _pid, uint256 _amount) external nonReentrant {
        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 multiplier = getBoostMultiplier(msg.sender, _pid);

        if (_amount > 0) {
            uint256 before = lpToken[_pid].balanceOf(address(this));
            lpToken[_pid].safeTransferFrom(msg.sender, address(this), _amount);
            _amount = lpToken[_pid].balanceOf(address(this)).sub(before);
            user.amount = user.amount.add(_amount);

            // Update total boosted share.
            pool.totalBoostedShare = pool.totalBoostedShare.add(_amount.mul(multiplier).div(BOOST_PRECISION));
        }

        user.rewardDebt = user.amount.mul(multiplier).div(BOOST_PRECISION).mul(pool.accTokenPerShare).div(
            ACC_TOKEN_PRECISION
        );
        poolInfo[_pid] = pool;

        _updateBoostMultiplier(msg.sender, _pid);

        emit Deposit(msg.sender, _pid, _amount);
    }

    /// @notice Withdraw LP tokens from pool.
    /// @param _pid The id of the pool. See `poolInfo`.
    /// @param _amount Amount of LP tokens to withdraw.
    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(user.amount >= _amount, "withdraw: Insufficient");

        _updateBoostMultiplier(msg.sender, _pid);

        uint256 multiplier = getBoostMultiplier(msg.sender, _pid);

        settlePendingToken(msg.sender, _pid, multiplier);

        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            lpToken[_pid].safeTransfer(msg.sender, _amount);
        }

        user.rewardDebt = user.amount.mul(multiplier).div(BOOST_PRECISION).mul(pool.accTokenPerShare).div(
            ACC_TOKEN_PRECISION
        );
        poolInfo[_pid].totalBoostedShare = poolInfo[_pid].totalBoostedShare.sub(
            _amount.mul(multiplier).div(BOOST_PRECISION)
        );

        emit Withdraw(msg.sender, _pid, _amount);
    }

    /// @notice Withdraw without caring about the rewards. EMERGENCY ONLY.
    /// @param _pid The id of the pool. See `poolInfo`.
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        _updateBoostMultiplier(msg.sender, _pid);

        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        uint256 boostedAmount = amount.mul(getBoostMultiplier(msg.sender, _pid)).div(BOOST_PRECISION);
        pool.totalBoostedShare = pool.totalBoostedShare > boostedAmount ? pool.totalBoostedShare.sub(boostedAmount) : 0;

        // Note: transfer can fail or succeed if `amount` is zero.
        lpToken[_pid].safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    function calcMultiplier(address _user, uint _pid) external view returns(uint) {
        uint newMultiplier = _calcMultiplier(_user, _pid);
        return newMultiplier > BOOST_PRECISION ? newMultiplier : BOOST_PRECISION;

    }

    function _calcMultiplier(address _user, uint _pid) internal view returns(uint) {
        // maxMultiplier = 8
        // temp = (100/maxMultiplier)

        // votingPower = lpAmount[user] * ( temp / 100 ) + ((( (totalLpAmount[pid] * votingBalance[user]) / votingTotal )) * (100- temp)) / 100
        // votingPower = min tra lpAmount e votingPower
        // multiplier = votingPower / lpAmount * maxMultiplier;
        uint PRECISION = 1e18;

        UserInfo memory _userInfo = userInfo[_pid][_user];
        IERC20 _lpToken = lpToken[_pid];

        uint lpAmount = _userInfo.amount;
        if ( lpAmount == 0) {
            return 1;
        }
        uint totalLpAmount = _lpToken.balanceOf(address(this));
        uint votingBalance = veContract.balanceOf(_user);
        uint votingTotal = veContract.totalSupply();

        uint firstTerm = (lpAmount * ((100 * PRECISION  / maxMultiplier) / 100)) / PRECISION;

        uint secondTerm = votingTotal > 0 ? ((totalLpAmount * votingBalance) / votingTotal) : 0;

        uint thirdTerm = (100 - ( 100 / maxMultiplier));

        uint votingPower = firstTerm + secondTerm * thirdTerm / 100;

        if (lpAmount < votingPower) {
            votingPower = lpAmount;
        }

        uint multiplier = (votingPower * PRECISION / lpAmount * maxMultiplier);

        return multiplier;
    }

    /// @notice Update user boost factor.
    /// @param _user The user address for boost factor updates.
    /// @param _pid The pool id for the boost factor updates.
    function updateBoostMultiplier(
        address _user,
        uint256 _pid
    ) external nonReentrant {
        _updateBoostMultiplier(_user, _pid);
    }

    function _updateBoostMultiplier(address _user, uint _pid) internal {
        require(_user != address(0), "MasterChefV2: The user address must be valid");

        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = userInfo[_pid][_user];

        uint256 prevMultiplier = getBoostMultiplier(_user, _pid);
        settlePendingToken(_user, _pid, prevMultiplier);

        uint newMultiplier = _calcMultiplier(_user, _pid);

        user.rewardDebt = user.amount.mul(newMultiplier).div(BOOST_PRECISION).mul(pool.accTokenPerShare).div(
            ACC_TOKEN_PRECISION
        );
        if(pool.totalBoostedShare > 0 ) {
            pool.totalBoostedShare = pool.totalBoostedShare.sub(user.amount.mul(prevMultiplier).div(BOOST_PRECISION)).add(
                user.amount.mul(newMultiplier).div(BOOST_PRECISION)
            );
        } else {
            pool.totalBoostedShare = pool.totalBoostedShare
            .add(
                user.amount.mul(newMultiplier).div(BOOST_PRECISION)
            );
        }
        poolInfo[_pid] = pool;
        userInfo[_pid][_user].boostMultiplier = newMultiplier;

        emit UpdateBoostMultiplier(_user, _pid, prevMultiplier, newMultiplier);
    }

    /// @notice Get user boost multiplier for specific pool id.
    /// @param _user The user address.
    /// @param _pid The pool id.
    function getBoostMultiplier(address _user, uint256 _pid) public view returns (uint256) {
        uint256 multiplier = userInfo[_pid][_user].boostMultiplier;
        return multiplier > BOOST_PRECISION ? multiplier : BOOST_PRECISION;
    }

    /// @notice Settles, distribute the pending TOKEN rewards for given user.
    /// @param _user The user address for settling rewards.
    /// @param _pid The pool id.
    /// @param _boostMultiplier The user boost multiplier in specific pool id.
    function settlePendingToken(
        address _user,
        uint256 _pid,
        uint256 _boostMultiplier
    ) internal {
        UserInfo memory user = userInfo[_pid][_user];

        uint256 boostedAmount = user.amount.mul(_boostMultiplier).div(BOOST_PRECISION);
        uint256 accToken = boostedAmount.mul(poolInfo[_pid].accTokenPerShare).div(ACC_TOKEN_PRECISION);
        uint256 pending = accToken.sub(user.rewardDebt);
        // SafeTransfer TOKEN
        _safeTransfer(_user, pending);
    }

    /// @notice Safe Transfer TOKEN.
    /// @param _to The TOKEN receiver address.
    /// @param _amount transfer TOKEN amounts.
    function _safeTransfer(address _to, uint256 _amount) internal {
        if (_amount > 0) {
            uint256 balance = TOKEN.balanceOf(address(this));
            if (balance < _amount) {
                _amount = balance;
            }
            TOKEN.safeTransfer(_to, _amount);
        }
    }
}
