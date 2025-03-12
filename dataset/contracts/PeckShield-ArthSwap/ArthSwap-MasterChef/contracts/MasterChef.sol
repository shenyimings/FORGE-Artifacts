// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "boring-solidity/contracts/libraries/BoringMath.sol";
import "boring-solidity/contracts/BoringBatchable.sol";
import "boring-solidity/contracts/BoringOwnable.sol";
import "./libraries/SignedSafeMath.sol";
import "./interfaces/IRewarder.sol";

/// @notice The MasterChef contract gives out ARSW tokens for yield farming.
/// The amount of ARSW token reward decreases per month (215000 blocks).
/// For the detail, see the token economics documents: https://docs.arthswap.org/arsw-token
contract MasterChef is BoringOwnable, BoringBatchable {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using BoringMath64 for uint64;
    using BoringERC20 for IERC20;
    using SignedSafeMath for int256;

    /// @notice Info of each MasterChef user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of ARSW entitled to the user.
    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
    }

    /// @notice Info of each MasterChef pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of ARSW to distribute per block.
    struct PoolInfo {
        uint128 accARSWPerShare;
        uint64 lastRewardBlock;
        uint64 allocPoint;
    }

    /// @notice Address of ARSW contract.
    IERC20 public immutable ARSW;

    /// @notice Info of each MasterChef pool.
    PoolInfo[] public poolInfos;
    /// @notice Address of the LP token for each MasterChef pool.
    IERC20[] public lpTokens;
    /// @notice Address of each `IRewarder` contract in MasterChef.
    IRewarder[] public rewarders;

    /// @notice Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfos;
    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;

    uint256 private constant ACC_ARSW_PRECISION = 1e12;
    /// @dev Block number of starting ARSW reward
    uint64 internal ARTHSWAP_ORIGIN_BLOCK = 242181;
    uint256 internal BLOCK_PER_PERIOD = 215000;
    /// @dev After MAX_PERIOD ARSW reward will end
    uint256 private constant MAX_PERIOD = 23;
    /// @notice Amount of ARSW reward per block in the first period
    uint256 public constant FIRST_PERIOD_REWERD_SUPPLY = 151629858171523000000;

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
        IERC20 indexed lpToken,
        IRewarder indexed rewarder
    );
    event LogSetPool(
        uint256 indexed pid,
        uint256 allocPoint,
        IRewarder indexed rewarder,
        bool overwrite
    );
    event LogUpdatePool(
        uint256 indexed pid,
        uint64 lastRewardBlock,
        uint256 lpSupply,
        uint256 accARSWPerShare
    );
    event DepositARSW(uint256 blockNumber, uint256 amount);

    /// @param arswToken The ARSW token contract address.
    constructor(IERC20 arswToken) public {
        ARSW = arswToken;
    }

    /// @dev Modifier to check that the pool is valid
    modifier validPool(uint256 pid) {
        require(pid < poolInfos.length, "MasterChef: invalid pool id");
        _;
    }

    /// @notice Returns the number of MasterChef pools.
    function poolLength() external view returns (uint256 pools) {
        pools = poolInfos.length;
    }

    /// @dev Prevent duplicate LP token
    function checkPoolDuplicate(IERC20 lpToken) internal view {
        for (uint256 pid = 0; pid < lpTokens.length; pid++) {
            require(lpTokens[pid] != lpToken, "MasterChef: duplicate LP token");
        }
    }

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param allocPoint AP of the new pool.
    /// @param lpToken Address of the LP ERC-20 token.
    /// @param rewarder Address of the rewarder delegate.
    function add(
        uint256 allocPoint,
        IERC20 lpToken,
        IRewarder rewarder
    ) external onlyOwner {
        checkPoolDuplicate(lpToken);
        updateAllPools();
        uint256 lastRewardBlock = block.number;
        totalAllocPoint = totalAllocPoint.add(allocPoint);
        lpTokens.push(lpToken);
        rewarders.push(rewarder);

        poolInfos.push(
            PoolInfo({
                allocPoint: allocPoint.to64(),
                lastRewardBlock: lastRewardBlock.to64(),
                accARSWPerShare: 0
            })
        );
        emit LogPoolAddition(
            lpTokens.length.sub(1),
            allocPoint,
            lpToken,
            rewarder
        );
    }

    /// @notice Update the given pool's ARSW allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param allocPoint New AP of the pool.
    /// @param rewarder Address of the rewarder delegate.
    /// @param overwrite True if rewarder should be `set`. Otherwise `rewarder` is ignored.
    function set(
        uint256 pid,
        uint256 allocPoint,
        IRewarder rewarder,
        bool overwrite
    ) external validPool(pid) onlyOwner {
        updateAllPools();
        totalAllocPoint = totalAllocPoint.sub(poolInfos[pid].allocPoint).add(
            allocPoint
        );
        poolInfos[pid].allocPoint = allocPoint.to64();
        if (overwrite) {
            rewarders[pid] = rewarder;
        }
        emit LogSetPool(
            pid,
            allocPoint,
            overwrite ? rewarder : rewarders[pid],
            overwrite
        );
    }

    /// @notice View function to see pending ARSW on frontend.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param user Address of user.
    /// @return pending ARSW reward for a given user.
    function pendingARSW(uint256 pid, address user)
        external
        view
        validPool(pid)
        returns (uint256 pending)
    {
        PoolInfo memory pool = poolInfos[pid];
        UserInfo storage userInfo = userInfos[pid][user];
        uint256 accARSWPerShare = pool.accARSWPerShare;
        uint256 lpSupply = lpTokens[pid].balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 additionalAccARSWPerShare = calculateAdditionalAccARSWPerShare(
                    pool,
                    block.number,
                    lpSupply
                );
            accARSWPerShare = accARSWPerShare.add(additionalAccARSWPerShare);
        }
        pending = int256(
            userInfo.amount.mul(accARSWPerShare) / ACC_ARSW_PRECISION
        ).sub(userInfo.rewardDebt).toUInt256();
    }

    /// @notice Update reward variables for selected pools. Be careful of gas spending!
    /// @param pids Pool IDs of all to be updated. Make sure to update all active pools.
    function massUpdatePools(uint256[] calldata pids) external {
        uint256 len = pids.length;
        for (uint256 i = 0; i < len; ++i) {
            updatePool(pids[i]);
        }
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    function updateAllPools() public {
        for (uint256 pid = 0; pid < poolInfos.length; ++pid) {
            updatePool(pid);
        }
    }

    /// @notice get period of the given blockNumber.
    /// @param blockNumber block number
    /// @return period period of the blockNumber
    function getPeriod(uint256 blockNumber)
        public
        view
        returns (uint256 period)
    {
        require(
            blockNumber >= ARTHSWAP_ORIGIN_BLOCK,
            "MasterChef: blockNumber should be greater than ARTHSWAP_ORIGIN_BLOCK"
        );
        return blockNumber.sub(ARTHSWAP_ORIGIN_BLOCK) / BLOCK_PER_PERIOD;
    }

    /// @notice get max block number in the given period.
    /// @param period period
    /// @return periodMaxBlock max block number in the period
    function periodMax(uint256 period)
        public
        view
        returns (uint256 periodMaxBlock)
    {
        return
            ARTHSWAP_ORIGIN_BLOCK
                .add(BLOCK_PER_PERIOD.mul(period.add(1)).to64())
                .sub(1);
    }

    /// @notice Calculates and returns the `amount` of ARSW per block.
    function ARSWPerBlock(uint256 period) public pure returns (uint256 amount) {
        if (period > MAX_PERIOD) {
            return 0;
        }

        return FIRST_PERIOD_REWERD_SUPPLY.mul(9**period) / (10**period);
    }

    /// @notice calculate additional accARSWPerShare of the given pool
    /// @param pool pool
    /// @param lpSupply sum deposit amount of the LP token by the pool
    /// @return additionalAccARSWPerShare additional accARSWPerShare
    function calculateAdditionalAccARSWPerShare(
        PoolInfo memory pool,
        uint256 currentBlock,
        uint256 lpSupply
    ) internal view returns (uint256 additionalAccARSWPerShare) {
        require(lpSupply > 0, "MasterChef: lpSupply should be greater than 0");
        uint256 lastRewardBlockPeriod = getPeriod(pool.lastRewardBlock);
        uint256 currentPeriod = getPeriod(currentBlock);

        // ARSWReward, lastBlock are mutable variable
        uint256 ARSWReward = 0;
        uint256 lastBlock = pool.lastRewardBlock;
        for (
            uint256 period = lastRewardBlockPeriod;
            period <= currentPeriod;
            period++
        ) {
            if (period > MAX_PERIOD) break;
            if (currentBlock <= periodMax(period)) {
                ARSWReward = ARSWReward.add(
                    currentBlock.sub(lastBlock).mul(ARSWPerBlock(period)).mul(
                        pool.allocPoint
                    ) / totalAllocPoint
                );
            } else {
                ARSWReward = ARSWReward.add(
                    periodMax(period)
                        .sub(lastBlock)
                        .mul(ARSWPerBlock(period))
                        .mul(pool.allocPoint) / totalAllocPoint
                );
                lastBlock = periodMax(period);
            }
        }

        return ARSWReward.mul(ACC_ARSW_PRECISION) / lpSupply;
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint256 pid)
        public
        validPool(pid)
        returns (PoolInfo memory pool)
    {
        pool = poolInfos[pid];
        if (block.number > pool.lastRewardBlock) {
            uint256 lpSupply = lpTokens[pid].balanceOf(address(this));
            if (lpSupply > 0) {
                uint256 additionalAccARSWPerShare = calculateAdditionalAccARSWPerShare(
                        pool,
                        block.number,
                        lpSupply
                    );
                pool.accARSWPerShare = pool.accARSWPerShare.add(
                    additionalAccARSWPerShare.to128()
                );
            }
            pool.lastRewardBlock = block.number.to64();
            poolInfos[pid] = pool;
            emit LogUpdatePool(
                pid,
                pool.lastRewardBlock,
                lpSupply,
                pool.accARSWPerShare
            );
        }
    }

    /// @notice Deposit LP tokens to MasterChef for ARSW allocation.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to deposit.
    /// @param to The receiver of `amount` deposit benefit.
    function deposit(
        uint256 pid,
        uint256 amount,
        address to
    ) external validPool(pid) {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfos[pid][to];

        // Effects
        user.amount = user.amount.add(amount);
        user.rewardDebt = user.rewardDebt.add(
            int256(amount.mul(pool.accARSWPerShare) / ACC_ARSW_PRECISION)
        );

        emit Deposit(msg.sender, pid, amount, to);

        // Interactions
        IRewarder rewarder = rewarders[pid];
        if (address(rewarder) != address(0)) {
            rewarder.onARSWReward(pid, to, to, 0, user.amount);
        }
        lpTokens[pid].safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Withdraw LP tokens from MasterChef.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param to Receiver of the LP tokens.
    function withdraw(
        uint256 pid,
        uint256 amount,
        address to
    ) external validPool(pid) {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfos[pid][msg.sender];
        require(amount > 0, "amount should not be 0");
        // Effects
        user.rewardDebt = user.rewardDebt.sub(
            int256(amount.mul(pool.accARSWPerShare) / ACC_ARSW_PRECISION)
        );

        user.amount = user.amount.sub(amount);

        emit Withdraw(msg.sender, pid, amount, to);

        // Interactions
        IRewarder rewarder = rewarders[pid];
        if (address(rewarder) != address(0)) {
            rewarder.onARSWReward(pid, msg.sender, to, 0, user.amount);
        }

        lpTokens[pid].safeTransfer(to, amount);
    }

    /// @notice Harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of ARSW rewards.
    function harvest(uint256 pid, address to) external validPool(pid) {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfos[pid][msg.sender];
        int256 accumulatedARSW = int256(
            user.amount.mul(pool.accARSWPerShare) / ACC_ARSW_PRECISION
        );
        uint256 _pendingARSW = accumulatedARSW.sub(user.rewardDebt).toUInt256();

        // Effects
        user.rewardDebt = accumulatedARSW;

        emit Harvest(msg.sender, pid, _pendingARSW);

        // Interactions
        if (_pendingARSW != 0) {
            ARSW.safeTransfer(to, _pendingARSW);
        }

        IRewarder rewarder = rewarders[pid];
        if (address(rewarder) != address(0)) {
            rewarder.onARSWReward(
                pid,
                msg.sender,
                to,
                _pendingARSW,
                user.amount
            );
        }
    }

    /// @notice Withdraw LP tokens from MasterChef and harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param to Receiver of the LP tokens and ARSW rewards.
    function withdrawAndHarvest(
        uint256 pid,
        uint256 amount,
        address to
    ) external validPool(pid) {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfos[pid][msg.sender];
        int256 accumulatedARSW = int256(
            user.amount.mul(pool.accARSWPerShare) / ACC_ARSW_PRECISION
        );
        uint256 _pendingARSW = accumulatedARSW.sub(user.rewardDebt).toUInt256();

        // Effects
        user.rewardDebt = accumulatedARSW.sub(
            int256(amount.mul(pool.accARSWPerShare) / ACC_ARSW_PRECISION)
        );
        user.amount = user.amount.sub(amount);

        emit Withdraw(msg.sender, pid, amount, to);
        emit Harvest(msg.sender, pid, _pendingARSW);

        // Interactions
        ARSW.safeTransfer(to, _pendingARSW);

        IRewarder rewarder = rewarders[pid];
        if (address(rewarder) != address(0)) {
            rewarder.onARSWReward(
                pid,
                msg.sender,
                to,
                _pendingARSW,
                user.amount
            );
        }

        lpTokens[pid].safeTransfer(to, amount);
    }

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of the LP tokens.
    function emergencyWithdraw(uint256 pid, address to)
        external
        validPool(pid)
    {
        UserInfo storage user = userInfos[pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        IRewarder rewarder = rewarders[pid];

        emit EmergencyWithdraw(msg.sender, pid, amount, to);

        if (address(rewarder) != address(0)) {
            rewarder.onARSWReward(pid, msg.sender, to, 0, 0);
        }

        // Note: transfer can fail or succeed if `amount` is zero.
        lpTokens[pid].safeTransfer(to, amount);
    }

    /// @notice send ARSW to MasterChef contract for user's farming
    /// @param amount amount of ARSW to deposit
    function depositARSW(uint256 amount) external onlyOwner {
        require(amount > 0, "MasterChef: amount should be greater than 0");
        emit DepositARSW(block.number, amount);
        ARSW.safeTransferFrom(msg.sender, address(this), amount);
    }
}
