// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockIchiFarm is Ownable {
    using SafeERC20 for IERC20;
    /// @notice Info of each IFV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of ICHI entitled to the user.
    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
    }

    /// @notice Info of each IFV2 pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of ICHI to distribute per block.
    struct PoolInfo {
        uint128 accIchiPerShare;
        uint64 lastRewardBlock;
        uint64 allocPoint;
    }

    /// @dev Address of ICHI contract.
    IERC20 private immutable ICHI;

    /// @notice Info of each IFV2 pool.
    PoolInfo[] public poolInfo;
    /// @notice Address of the LP token for each IFV2 pool.
    IERC20[] public lpToken;
    /// @dev List of all added LP tokens.
    mapping(address => bool) private addedLPs;

    /// @notice Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    /// @notice Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;

    /// @notice ICHI tokens created per block.
    uint256 public ichiPerBlock;

    /// @dev Extra decimals for pool's accIchiPerShare attribute. Needed in order to accomodate different types of LPs.
    uint256 private constant ACC_ICHI_PRECISION = 1e18;

    /// @dev nonReentrant flag used to secure functions with external calls.
    bool private nonReentrant;

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
    event LogPoolAddition(
        uint256 indexed pid,
        uint256 allocPoint,
        IERC20 indexed lpToken
    );
    event LogSetPool(uint256 indexed pid, uint256 allocPoint);
    event LogUpdatePool(
        uint256 indexed pid,
        uint64 lastRewardBlock,
        uint256 lpSupply,
        uint256 accIchiPerShare
    );
    event SetIchiPerBlock(uint256 ichiPerBlock, bool withUpdate);

    /// @param _ichi The ICHI token contract address.
    /// @param _ichiPerBlock ICHI tokens created per block.
    constructor(IERC20 _ichi, uint256 _ichiPerBlock) {
        ICHI = _ichi;
        ichiPerBlock = _ichiPerBlock;
        totalAllocPoint = 0;
    }

    /// @notice Update number of ICHI tokens created per block. Can only be called by the owner.
    /// @param _ichiPerBlock ICHI tokens created per block.
    /// @param _withUpdate true if massUpdatePools should be triggered as well.
    function setIchiPerBlock(uint256 _ichiPerBlock, bool _withUpdate)
        external
        onlyOwner
    {
        if (_withUpdate) {
            massUpdateAllPools();
        }
        ichiPerBlock = _ichiPerBlock;
        emit SetIchiPerBlock(_ichiPerBlock, _withUpdate);
    }

    /// @notice Set the nonReentrant flag. Could be used to pause/resume the farm operations. Can only be called by the owner.
    /// @param _val nonReentrant flag value to be set.
    function setNonReentrant(bool _val) external onlyOwner returns (bool) {
        nonReentrant = _val;
        return nonReentrant;
    }

    /// @notice Returns the number of IFV2 pools.
    function poolLength() external view returns (uint256 pools) {
        pools = poolInfo.length;
    }

    /// @notice Returns the ICHI reward value for a specific pool.
    function poolIchiReward(uint256 _pid) external view returns (uint256) {
        if (totalAllocPoint == 0) return 0;
        return (ichiPerBlock * (poolInfo[_pid].allocPoint)) / totalAllocPoint;
    }

    /// @notice Returns the total number of LPs staked in the farm.
    function getLPSupply(uint256 _pid) external view returns (uint256) {
        uint256 lpSupply = lpToken[_pid].balanceOf(address(this));
        return lpSupply;
    }

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param allocPoint AP of the new pool.
    /// @param _lpToken Address of the LP ERC-20 token.
    function add(uint256 allocPoint, IERC20 _lpToken) external onlyOwner {
        require(
            !addedLPs[address(_lpToken)],
            "ichiFarmV2::there is already a pool with this LP"
        );
        uint256 lastRewardBlock = block.number;
        totalAllocPoint += allocPoint;
        lpToken.push(_lpToken);
        addedLPs[address(_lpToken)] = true;

        poolInfo.push(
            PoolInfo({
                allocPoint: uint64(allocPoint),
                lastRewardBlock: uint64(lastRewardBlock),
                accIchiPerShare: 0
            })
        );
        emit LogPoolAddition(lpToken.length - 1, allocPoint, _lpToken);
    }

    /// @notice Update the given pool's ICHI allocation point. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    function set(uint256 _pid, uint256 _allocPoint) external onlyOwner {
        totalAllocPoint =
            totalAllocPoint -
            poolInfo[_pid].allocPoint +
            _allocPoint;
        poolInfo[_pid].allocPoint = uint64(_allocPoint);
        emit LogSetPool(_pid, _allocPoint);
    }

    /// @notice View function to see pending ICHI on frontend.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending ICHI reward for a given user.
    function pendingIchi(uint256 _pid, address _user)
        external
        view
        returns (uint256 pending)
    {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accIchiPerShare = pool.accIchiPerShare;
        uint256 lpSupply = lpToken[_pid].balanceOf(address(this));
        if (
            block.number > pool.lastRewardBlock &&
            lpSupply > 0 &&
            totalAllocPoint > 0
        ) {
            uint256 blocks = block.number - pool.lastRewardBlock;
            accIchiPerShare +=
                ((blocks *
                    ichiPerBlock *
                    pool.allocPoint *
                    ACC_ICHI_PRECISION) / totalAllocPoint) /
                lpSupply;
        }
        pending =
            (user.amount * accIchiPerShare) /
            ACC_ICHI_PRECISION -
            uint256(user.rewardDebt);
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    function massUpdateAllPools() public {
        uint256 len = poolInfo.length;
        for (uint256 pid = 0; pid < len; ++pid) {
            updatePool(pid);
        }
    }

    /// @notice Update reward variables for specified pools. Be careful of gas spending!
    /// @param pids Pool IDs of all to be updated. Make sure to update all active pools.
    function massUpdatePools(uint256[] calldata pids) external {
        uint256 len = pids.length;
        for (uint256 i = 0; i < len; ++i) {
            updatePool(pids[i]);
        }
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint256 pid) public returns (PoolInfo memory pool) {
        pool = poolInfo[pid];
        if (block.number > pool.lastRewardBlock) {
            uint256 lpSupply = lpToken[pid].balanceOf(address(this));
            if (lpSupply > 0 && totalAllocPoint > 0) {
                uint256 blocks = block.number - pool.lastRewardBlock;
                pool.accIchiPerShare += uint128(
                    ((blocks *
                        ichiPerBlock *
                        pool.allocPoint *
                        ACC_ICHI_PRECISION) / totalAllocPoint) / lpSupply
                );
            }
            pool.lastRewardBlock = uint64(block.number);
            poolInfo[pid] = pool;
            emit LogUpdatePool(
                pid,
                pool.lastRewardBlock,
                lpSupply,
                pool.accIchiPerShare
            );
        }
    }

    /// @notice Deposit LP tokens to IFV2 for ICHI allocation.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to deposit.
    /// @param to The receiver of `amount` deposit benefit.
    function deposit(
        uint256 pid,
        uint256 amount,
        address to
    ) external {
        require(!nonReentrant, "ichiFarmV2::nonReentrant - try again");
        nonReentrant = true;

        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][to];

        // Effects
        user.amount += amount;
        user.rewardDebt += int256(
            (amount * pool.accIchiPerShare) / ACC_ICHI_PRECISION
        );

        // Interactions
        lpToken[pid].safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, pid, amount, to);
        nonReentrant = false;
    }

    /// @notice Withdraw LP tokens from IFV2.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param to Receiver of the LP tokens.
    function withdraw(
        uint256 pid,
        uint256 amount,
        address to
    ) external {
        require(!nonReentrant, "ichiFarmV2::nonReentrant - try again");
        nonReentrant = true;

        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][msg.sender];

        // Effects
        user.rewardDebt -= int256(
            (amount * pool.accIchiPerShare) / ACC_ICHI_PRECISION
        );
        user.amount -= amount;

        // Interactions
        lpToken[pid].safeTransfer(to, amount);

        emit Withdraw(msg.sender, pid, amount, to);
        nonReentrant = false;
    }

    /// @notice Harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of ICHI rewards.
    function harvest(uint256 pid, address to) external {
        require(!nonReentrant, "ichiFarmV2::nonReentrant - try again");
        nonReentrant = true;

        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][msg.sender];
        int256 accumulatedIchi = int256(
            (user.amount * pool.accIchiPerShare) / ACC_ICHI_PRECISION
        );
        uint256 _pendingIchi = uint256(accumulatedIchi - user.rewardDebt);

        // Effects
        user.rewardDebt = accumulatedIchi;

        // Interactions
        if (_pendingIchi > 0) {
            ICHI.safeTransfer(to, _pendingIchi);
        }

        emit Harvest(msg.sender, pid, _pendingIchi);
        nonReentrant = false;
    }

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of the LP tokens.
    function emergencyWithdraw(uint256 pid, address to) public {
        require(address(0) != to, "ichiFarmV2::can't withdraw to address zero");
        UserInfo storage user = userInfo[pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        // Note: transfer can fail or succeed if `amount` is zero.
        lpToken[pid].safeTransfer(to, amount);
        emit EmergencyWithdraw(msg.sender, pid, amount, to);
    }
}
