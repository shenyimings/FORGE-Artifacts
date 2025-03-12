// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity >=0.8.0;

library SafeMath {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "SafeMath: ds-math-add-overflow");
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "SafeMath: ds-math-sub-underflow");
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(
            y == 0 || (z = x * y) / y == x,
            "SafeMath: ds-math-mul-overflow"
        );
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: Caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: New owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool);

    function transfer(address, uint256) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

library SafeERC20 {
    using SafeMath for uint256;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
    }

    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves.

        // A Solidity high level call has three parts:
        //  1. The target address is checked to verify it contains contract code
        //  2. The call itself is made, and success asserted
        //  3. The return value is decoded, which in turn checks the size of the returned data.
        // solhint-disable-next-line max-line-length

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(
                abi.decode(returndata, (bool)),
                "SafeERC20: ERC20 operation did not succeed"
            );
        }
    }
}

// File contracts/SmartBaryFactoryRewarder.sol
/// @title Smart Baryon Factory Rewarder
/// @notice Pool to hold reward minted from SmartBaryFactory
contract SmartBaryFactoryRewarder {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20[] public rewardTokens;
    uint256[] public rewardMultipliers;
    address private FACTORY_V2;

    /// @dev Maximum reward tokens can claim in single pool
    uint256 private constant MAX_REWARDS = 100;

    /// @dev Reward quantities remain for users
    mapping(address => mapping(uint256 => uint256)) private rewardDebts;

    /// @param _factoryV2 The address of the factory contract
    constructor(address _factoryV2) {
        require(
            _factoryV2 != address(0),
            "SmartBaryFactoryRewarder: Invalid factory address"
        );

        FACTORY_V2 = _factoryV2;
    }

    modifier onlyBaryonFactory() {
        require(
            msg.sender == FACTORY_V2,
            "Only BaryonFactory can call this function."
        );
        _;
    }

    /// @param _rewardTokens The address of each reward token
    /// @param _rewardMultipliers The amount of each reward token to be claimable
    /// @notice Each reward multiplier should matching with each reward tokens index
    function initialize(
        IERC20[] memory _rewardTokens,
        uint256[] memory _rewardMultipliers
    ) public onlyBaryonFactory {
        require(
            _rewardTokens.length > 0 &&
                _rewardTokens.length <= MAX_REWARDS &&
                _rewardTokens.length == _rewardMultipliers.length,
            "SmartBaryFactoryRewarder: Invalid input lengths"
        );

        for (uint256 i; i < _rewardTokens.length; ++i) {
            require(
                address(_rewardTokens[i]) != address(0),
                "SmartBaryFactoryRewarder: Cannot reward zero address"
            );
            require(
                _rewardMultipliers[i] > 0,
                "SmartBaryFactoryRewarder: Invalid multiplier"
            );
        }

        rewardTokens = _rewardTokens;
        rewardMultipliers = _rewardMultipliers;
    }

    /// @param user The address of deposit user
    /// @param harvestAmount The amount user can be claimable
    /// @notice Must deposit first before user can be claimed
    function claimReward(address user, uint256 harvestAmount)
        external
        onlyBaryonFactory
    {
        for (uint256 i; i < rewardTokens.length; ++i) {
            uint256 pendingReward = rewardDebts[user][i].add(
                harvestAmount.mul(rewardMultipliers[i])
            );

            uint256 rewardBal = rewardTokens[i].balanceOf(address(this));
            require(
                rewardBal > 0,
                "SmartBaryFactoryRewarder: Reward Balances must be greater than 0"
            );
            bool isOverPool = pendingReward >= rewardBal;

            rewardDebts[user][i] = isOverPool
                ? pendingReward.sub(rewardBal)
                : 0;
            uint256 claimRewardAmount = isOverPool ? rewardBal : pendingReward;
            if (claimRewardAmount > 0) {
                rewardTokens[i].safeTransfer(user, claimRewardAmount);
            }
        }
    }

    /// @param user The address of deposit user
    /// @param harvestAmount The amount user can be claimable
    /// @notice Return current pending reward of deposit user
    function pendingClaimable(address user, uint256 harvestAmount)
        external
        view
        returns (IERC20[] memory tokens, uint256[] memory amounts)
    {
        amounts = new uint256[](rewardTokens.length);
        for (uint256 i; i < rewardTokens.length; ++i) {
            uint256 pendingReward = rewardDebts[user][i].add(
                harvestAmount.mul(rewardMultipliers[i])
            );
            uint256 rewardBal = rewardTokens[i].balanceOf(address(this));
            amounts[i] = pendingReward >= rewardBal ? rewardBal : pendingReward;
        }
        return (rewardTokens, amounts);
    }

    /// @notice Current state of reward tokens
    function getRewardTokens() external view returns (IERC20[] memory) {
        return rewardTokens;
    }

    /// @notice Current state of reward multipliers
    function getRewardMultipliers() external view returns (uint256[] memory) {
        return rewardMultipliers;
    }

    /// @notice Baryon owner withdraw all tokens from pool
    function withdrawForOwner() external onlyBaryonFactory {
        for (uint256 i; i < rewardTokens.length; ++i) {
            uint256 tokenBalance = rewardTokens[i].balanceOf(address(this));

            if (tokenBalance > 0) {
                rewardTokens[i].safeTransfer(FACTORY_V2, tokenBalance);
            }
        }
    }

    /// @notice Baryon owner withdraw tokens from pool
    function withdrawTokens(address[] memory tokens)
        external
        onlyBaryonFactory
    {
        for (uint256 i; i < tokens.length; ++i) {
            IERC20 _token = IERC20(tokens[i]);
            uint256 tokenBalance = _token.balanceOf(address(this));

            if (tokenBalance > 0) {
                _token.safeTransfer(FACTORY_V2, tokenBalance);
            }
        }
    }
}

/// @title Smart Baryon Factory
/// @notice Factory contract gives out a reward tokens per block.
contract SmartBaryFactory is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /// @notice Info of each Deposited user.
    /// `amount` LP token amount
    /// `rewardDebt` The amount of user reward
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    /// @notice Info of each pool.
    /// `rewardsStartTime` Block time when the rewards start to claimable.
    /// `accRewardPerShare` Each reward per share by total LP Supply
    /// `rewardsExpiration` Block time when the rewards per second stops.
    /// `lastRewardTime` Lastest pool reward updated
    /// `rewardPerSeconds` Reward to be claimable by seconds
    struct PoolInfo {
        uint256 rewardsStartTime;
        uint256 accRewardPerShare;
        uint256 rewardsExpiration;
        uint256 lastRewardTime;
        uint256 rewardPerSeconds;
    }

    /// @notice Info of each pool pool.
    PoolInfo[] public poolInfo;
    /// @notice Address of the LP token for each pool pool.
    IERC20[] public lpToken;
    /// @notice Address of each `SmartBaryFactoryRewarder` contract in pool.
    SmartBaryFactoryRewarder[] public rewarder;
    /// @notice Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    /// @dev List LP tokens already added
    mapping(address => bool) public listAddedLPs;

    uint256 private constant ACC_REWARD_PRECISION = 1e12;

    event Deposit(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        address indexed to
    );
    event Withdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        address indexed to
    );
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        address indexed to
    );
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);

    event PoolAdded(
        uint256 indexed pid,
        uint256 rewardsStartTime,
        uint256 rewardsExpiration,
        uint256 rewardPerSecond,
        IERC20 indexed lpToken,
        address rewarder
    );
    event PoolSet(
        uint256 indexed pid,
        uint256 rewardsStartTime,
        uint256 rewardsExpiration,
        uint256 rewardPerSecond,
        SmartBaryFactoryRewarder indexed rewarder,
        bool overwrite
    );
    event PoolUpdate(
        uint256 indexed pid,
        uint256 lastRewardTime,
        uint256 lpSupply,
        uint256 accRewardPerShare
    );

    /// @notice Returns the size of all current pools.
    function poolLength() public view returns (uint256 pools) {
        pools = poolInfo.length;
    }

    /// @notice Returns list of all lpTokens already added
    function lpTokens() external view returns (IERC20[] memory) {
        return lpToken;
    }

    /// @notice Check Block time start condition of each pool
    /// @param pool Pool to check block time
    function farmCheckStartTime(PoolInfo memory pool) internal view {
        require(
            block.timestamp >= pool.rewardsStartTime,
            "BaryonFarmV2: Invalid Start Time"
        );
    }

    /// @notice Check Block expiration time
    /// @param pool Pool to check block time
    function farmCheckExpirationTime(PoolInfo memory pool) internal view {
        require(
            block.timestamp < pool.rewardsExpiration,
            "BaryonFarmV2: Invalid Expiration Time"
        );
    }

    /// @notice Add rewarder pool
    function addPool(
        IERC20[] memory _rewardTokens,
        uint256[] memory _rewardMultipliers,
        uint256 _rewardsStartTime,
        uint256 _rewardPerSeconds,
        uint256 _rewardsExpiration,
        address _lpToken
    ) external onlyOwner {
        uint256 tokenCode;
        assembly {
            tokenCode := extcodesize(_lpToken)
        }
        IERC20 lpTokenCall = IERC20(_lpToken);
        require(
            tokenCode > 0 && lpTokenCall.balanceOf(address(this)) >= 0,
            "SmartBaryFactory: Invalid token code"
        );

        massUpdateAllPools();
        add(
            _rewardTokens,
            _rewardMultipliers,
            _rewardsStartTime,
            _rewardPerSeconds,
            _rewardsExpiration,
            lpTokenCall
        );
    }

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once.
    function add(
        IERC20[] memory _rewardTokens,
        uint256[] memory _rewardMultipliers,
        uint256 _rewardsStartTime,
        uint256 _rewardPerSeconds,
        uint256 _rewardsExpiration,
        IERC20 _lpToken
    ) internal {
        require(
            listAddedLPs[address(_lpToken)] == false,
            "SmartBaryFactory: LP token already added"
        );

        bytes memory bytecode = type(SmartBaryFactoryRewarder).creationCode;
        bytecode = abi.encodePacked(bytecode, abi.encode(address(this)));
        bytes32 salt = keccak256(abi.encodePacked(_lpToken, _rewardsStartTime));
        address baryonFarmRewarder;

        assembly {
            baryonFarmRewarder := create2(
                0,
                add(bytecode, 32),
                mload(bytecode),
                salt
            )
        }

        SmartBaryFactoryRewarder(baryonFarmRewarder).initialize(
            _rewardTokens,
            _rewardMultipliers
        );

        lpToken.push(_lpToken);
        rewarder.push(SmartBaryFactoryRewarder(baryonFarmRewarder));

        poolInfo.push(
            PoolInfo({
                rewardsStartTime: _rewardsStartTime,
                rewardsExpiration: _rewardsExpiration,
                rewardPerSeconds: _rewardPerSeconds,
                lastRewardTime: block.timestamp,
                accRewardPerShare: 0
            })
        );

        listAddedLPs[address(_lpToken)] = true;
        emit PoolAdded(
            lpToken.length.sub(1),
            _rewardsStartTime,
            _rewardsExpiration,
            _rewardPerSeconds,
            _lpToken,
            baryonFarmRewarder
        );
    }

    /// @notice Change information for one pool
    function setPool(
        uint256 _pid,
        uint256 _rewardsStartTime,
        uint256 _rewardsExpiration,
        uint256 _rewardPerSeconds,
        SmartBaryFactoryRewarder _rewarder,
        bool overwrite
    ) external onlyOwner {
        massUpdateAllPools();
        set(
            _pid,
            _rewardsStartTime,
            _rewardsExpiration,
            _rewardPerSeconds,
            _rewarder,
            overwrite
        );
    }

    /// @notice Update the given pool's information
    function set(
        uint256 _pid,
        uint256 _rewardsStartTime,
        uint256 _rewardsExpiration,
        uint256 _rewardPerSeconds,
        SmartBaryFactoryRewarder _rewarder,
        bool overwrite
    ) internal {
        poolInfo[_pid].rewardsStartTime = _rewardsStartTime;
        poolInfo[_pid].rewardsExpiration = _rewardsExpiration;
        poolInfo[_pid].rewardPerSeconds = _rewardPerSeconds;
        if (overwrite) {
            rewarder[_pid] = _rewarder;
        }
        emit PoolSet(
            _pid,
            _rewardsStartTime,
            _rewardsExpiration,
            _rewardPerSeconds,
            overwrite ? _rewarder : rewarder[_pid],
            overwrite
        );
    }

    /// @notice Getter the pending reward for a given user.
    /// @param _pid The index of pool.
    /// @param _user Address of user.
    /// @return pending reward for a given user.
    function pendingReward(uint256 _pid, address _user)
        external
        view
        returns (uint256 pending)
    {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = lpToken[_pid].balanceOf(address(this));

        if (block.timestamp < pool.rewardsStartTime) {
            pending = 0;
        } else {
            if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
                uint256 time = block.timestamp <= pool.rewardsExpiration
                    ? block.timestamp.sub(pool.lastRewardTime) // Accrue rewards until now
                    : pool.rewardsExpiration > pool.lastRewardTime
                    ? pool.rewardsExpiration.sub(pool.lastRewardTime) // Accrue rewards until expiration
                    : 0; // No rewards to accrue
                uint256 reward = time.mul(pool.rewardPerSeconds);
                accRewardPerShare = accRewardPerShare.add(
                    reward.mul(ACC_REWARD_PRECISION) / lpSupply
                );
            }
            pending = uint256(
                user.amount.mul(accRewardPerShare) / ACC_REWARD_PRECISION
            ).sub(user.rewardDebt);
        }
    }

    /// @notice Update reward variables for all pools
    /// @param pids Pool IDs of all to be updated
    function massUpdatePools(uint256[] calldata pids) external {
        uint256 len = pids.length;
        for (uint256 i = 0; i < len; ++i) {
            updatePool(pids[i]);
        }
    }

    /// @notice Update reward variables for all pools.
    function massUpdateAllPools() public {
        uint256 len = poolInfo.length;
        for (uint256 pid = 0; pid < len; ++pid) {
            updatePool(pid);
        }
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool.
    /// @return pool Returns the pool updated.
    function updatePool(uint256 pid) public returns (PoolInfo memory pool) {
        pool = poolInfo[pid];
        if (
            block.timestamp > pool.lastRewardTime &&
            block.timestamp > pool.rewardsStartTime
        ) {
            uint256 lpSupply = lpToken[pid].balanceOf(address(this));
            if (lpSupply > 0) {
                uint256 time = block.timestamp <= pool.rewardsExpiration
                    ? block.timestamp.sub(pool.lastRewardTime) // Accrue rewards until now
                    : pool.rewardsExpiration > pool.lastRewardTime
                    ? pool.rewardsExpiration.sub(pool.lastRewardTime) // Accrue rewards until expiration
                    : 0; // No rewards to accrue
                uint256 reward = time.mul(pool.rewardPerSeconds);
                pool.accRewardPerShare = pool.accRewardPerShare.add(
                    (reward.mul(ACC_REWARD_PRECISION) / lpSupply)
                );
            }
            pool.lastRewardTime = block.timestamp;
            poolInfo[pid] = pool;
            emit PoolUpdate(
                pid,
                pool.lastRewardTime,
                lpSupply,
                pool.accRewardPerShare
            );
        }
    }

    /// @notice Deposit LP tokens to Pool for reward allocation.
    /// @param pid The index of the pool.
    /// @param amount LP token amount to deposit.
    function deposit(uint256 pid, uint256 amount) public {
        PoolInfo memory pool = updatePool(pid);
        farmCheckStartTime(pool);
        farmCheckExpirationTime(pool);

        address to = msg.sender;

        UserInfo storage user = userInfo[pid][to];
        lpToken[pid].safeTransferFrom(to, address(this), amount);

        uint256 accumulatedReward = uint256(
            user.amount.mul(pool.accRewardPerShare) / ACC_REWARD_PRECISION
        );
        uint256 _pendingReward = accumulatedReward.sub(user.rewardDebt);

        SmartBaryFactoryRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.claimReward(to, _pendingReward);
        }

        // Updated information
        user.amount = user.amount.add(amount);
        user.rewardDebt = accumulatedReward.add(
            uint256(amount.mul(pool.accRewardPerShare) / ACC_REWARD_PRECISION)
        );

        emit Deposit(to, pid, amount, to);
    }

    /// @notice Harvest reward for deposited user
    /// @param pid The index of the pool.
    function harvest(uint256 pid) public {
        PoolInfo memory pool = updatePool(pid);
        farmCheckStartTime(pool);

        address to = msg.sender;

        UserInfo storage user = userInfo[pid][to];
        uint256 accumulatedReward = uint256(
            user.amount.mul(pool.accRewardPerShare) / ACC_REWARD_PRECISION
        );
        uint256 _pendingReward = accumulatedReward.sub(user.rewardDebt);

        // Updated information
        user.rewardDebt = accumulatedReward;

        SmartBaryFactoryRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.claimReward(to, _pendingReward);
        }

        emit Harvest(to, pid, _pendingReward);
    }

    /// @notice Withdraw LP tokens from Factory and harvest reward for deposited user.
    /// @param pid The index of the pool.
    /// @param amount LP token amount to withdraw.
    function withdrawAndHarvest(uint256 pid, uint256 amount) public {
        PoolInfo memory pool = updatePool(pid);
        farmCheckStartTime(pool);
        address to = msg.sender;

        UserInfo storage user = userInfo[pid][to];
        uint256 accumulatedReward = uint256(
            user.amount.mul(pool.accRewardPerShare) / ACC_REWARD_PRECISION
        );
        uint256 _pendingReward = accumulatedReward.sub(user.rewardDebt);

        // Updated information
        user.rewardDebt = accumulatedReward.sub(
            uint256(amount.mul(pool.accRewardPerShare) / ACC_REWARD_PRECISION)
        );
        user.amount = user.amount.sub(amount);

        SmartBaryFactoryRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.claimReward(to, _pendingReward);
        }

        lpToken[pid].safeTransfer(to, amount);

        emit Withdraw(to, pid, amount, to);
        emit Harvest(to, pid, _pendingReward);
    }

    /// @notice Emergency withdraw without caring about rewards. EMERGENCY ONLY.
    /// @param pid The index of the pool.
    function emergencyWithdraw(uint256 pid) public {
        address to = msg.sender;

        UserInfo storage user = userInfo[pid][to];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        lpToken[pid].safeTransfer(to, amount);
        emit EmergencyWithdraw(to, pid, amount, to);
    }

    /// @notice Withdraw all token reward in pool
    /// @param pid The index of the pool.
    function withdrawMultiplePool(uint256[] calldata pid) public onlyOwner {
        for (uint256 i = 0; i < pid.length; i++) {
            SmartBaryFactoryRewarder _rewarder = rewarder[pid[i]];
            if (address(_rewarder) != address(0)) {
                _rewarder.withdrawForOwner();
            }
        }
    }

    /// @notice Withdraw the token from the pool
    /// @param pid The index of the pool.
    /// @param tokens The token contract token that want to withdraw of the pool
    function withdrawPoolTokens(uint256 pid, address[] calldata tokens)
        public
        onlyOwner
    {
        SmartBaryFactoryRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.withdrawTokens(tokens);
        }
    }

    /// @notice Update reward infomation
    /// @param pid The index of the pool.
    /// @param _rewardTokens The The contract of token reward.
    /// @param _rewardMultipliers The amount of each additional reward token to be claimable
    function setRewardConfig(
        uint256 pid,
        IERC20[] memory _rewardTokens,
        uint256[] memory _rewardMultipliers
    ) public onlyOwner {
        SmartBaryFactoryRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.initialize(_rewardTokens, _rewardMultipliers);
        }
    }

    /// @notice Withdraw all token from all pool
    /// @param tokens The token contract that want to withdraw from all pool
    function withdrawMultiple(address[] calldata tokens) public onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20 token = IERC20(tokens[i]);

            uint256 tokenBalance = token.balanceOf(address(this));
            if (tokenBalance > 0) {
                token.safeTransfer(msg.sender, tokenBalance);
            }
        }
    }
}
