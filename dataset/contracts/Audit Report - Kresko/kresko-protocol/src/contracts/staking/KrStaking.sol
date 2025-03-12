// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IKrStaking} from "./interfaces/IKrStaking.sol";

contract KrStaking is AccessControlUpgradeable, ReentrancyGuardUpgradeable, IKrStaking {
    using SafeERC20 for IERC20;

    // keccak256("kresko.operator.role")
    bytes32 public constant OPERATOR_ROLE = 0x8952ae23cc3fea91b9dba0cefa16d18a26ca2bf124b54f42b5d04bce3aacecd2;

    /**
     * ==================================================
     * =============== Storage ==========================
     * ==================================================
     */

    // Info of each staked user.
    mapping(uint256 => mapping(address => UserInfo)) private _userInfo;

    // Reward token drip per block
    mapping(address => uint256) public rewardPerBlockFor;

    // Info of each pool.
    PoolInfo[] private _poolInfo;

    // Total allocation points.
    uint128 public totalAllocPoint;

    /**
     * ==================================================
     * ============== Events ============================
     * ==================================================
     */

    event Deposit(address indexed user, uint256 indexed pid, uint256 indexed amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 indexed amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 indexed amount);
    event ClaimRewards(address indexed user, address indexed rewardToken, uint256 indexed amount);

    /**
     * ==================================================
     * ============== Initializer =======================
     * ==================================================
     */

    /**
     * @notice Initialize the contract with a single pool
     * @notice Sets initial reward token and rates
     * @notice Sets the caller as DEFAULT_ADMIN
     */
    function initialize(
        address[] calldata _rewardTokens,
        uint256[] calldata _rewardPerBlocks,
        IERC20 _depositToken,
        uint128 _allocPoint,
        uint128 _startBlock,
        address _admin,
        address _operator
    ) external initializer {
        require(_rewardPerBlocks.length == _rewardTokens.length, "Reward tokens must have a rewardPerBlock value");

        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(OPERATOR_ROLE, _operator);
        _setupRole(OPERATOR_ROLE, msg.sender);

        // Set initial reward tokens and allocations
        for (uint256 i; i < _rewardTokens.length; i++) {
            rewardPerBlockFor[_rewardTokens[i]] = _rewardPerBlocks[i];
        }

        // Push the initial pool in.
        _poolInfo.push(
            PoolInfo({
                depositToken: _depositToken,
                allocPoint: _allocPoint,
                lastRewardBlock: _startBlock,
                accRewardPerShares: new uint256[](_rewardTokens.length),
                rewardTokens: _rewardTokens
            })
        );

        totalAllocPoint += _allocPoint;
    }

    /**
     * ==================================================
     * =============== Modifiers ========================
     * ==================================================
     */

    /**
     * @notice Ensures no pool exists with this depositToken
     * @param _depositToken to check
     */
    modifier ensurePoolDoesNotExist(IERC20 _depositToken) {
        for (uint256 i; i < _poolInfo.length; i++) {
            require(address(_poolInfo[i].depositToken) != address(_depositToken), "KR: poolExists");
        }
        _;
    }

    /**
     * @notice Ensures this pool exists
     * @param _pid to check
     */
    modifier ensurePoolExists(uint256 _pid) {
        require(address(_poolInfo[_pid].depositToken) != address(0), "KR: !poolExists");
        _;
    }

    /**
     * ==================================================
     * ================== Views =========================
     * ==================================================
     */

    /// @inheritdoc IKrStaking
    function pendingRewards(uint256 _pid, address _user) public view returns (Reward memory rewards) {
        PoolInfo memory pool = _poolInfo[_pid];
        UserInfo memory user = _userInfo[_pid][_user];
        uint256 depositTokenSupply = pool.depositToken.balanceOf(address(this));
        uint256 rewardTokensLength = pool.rewardTokens.length;

        rewards = Reward({pid: _pid, tokens: pool.rewardTokens, amounts: new uint256[](rewardTokensLength)});

        if (depositTokenSupply != 0 && user.amount > 0) {
            for (uint256 rewardIndex; rewardIndex < rewardTokensLength; rewardIndex++) {
                uint256 accRewardPerShare = pool.accRewardPerShares[rewardIndex];

                uint256 rewardPerBlock = rewardPerBlockFor[pool.rewardTokens[rewardIndex]];
                uint256 blocks = block.number - pool.lastRewardBlock;
                uint256 reward = (rewardPerBlock * blocks * pool.allocPoint) / totalAllocPoint;

                accRewardPerShare += (reward * 1e12) / depositTokenSupply;

                rewards.amounts[rewardIndex] = (user.amount * accRewardPerShare) / 1e12 - user.rewardDebts[rewardIndex];
                rewards.tokens[rewardIndex] = pool.rewardTokens[rewardIndex];
            }
        }
    }

    /// @inheritdoc IKrStaking
    function allPendingRewards(address _account) external view returns (Reward[] memory allRewards) {
        allRewards = new Reward[](_poolInfo.length);
        for (uint256 pid; pid < _poolInfo.length; pid++) {
            Reward memory poolReward = pendingRewards(pid, _account);
            allRewards[pid] = poolReward;
        }
    }

    /// @inheritdoc IKrStaking
    function poolLength() external view returns (uint256) {
        return _poolInfo.length;
    }

    /// @inheritdoc IKrStaking
    function poolInfo(uint256 _pid) external view returns (PoolInfo memory) {
        return _poolInfo[_pid];
    }

    /// @inheritdoc IKrStaking
    function getPidFor(address _depositToken) external view returns (uint256 pid, bool found) {
        for (pid; pid < _poolInfo.length; pid++) {
            if (address(_poolInfo[pid].depositToken) == _depositToken) {
                found = true;
                break;
            }
        }
    }

    /// @inheritdoc IKrStaking
    function userInfo(uint256 _pid, address _account) external view returns (UserInfo memory) {
        return _userInfo[_pid][_account];
    }

    /**
     * ==================================================
     * =========== Core public functions ================
     * ==================================================
     */

    /// @inheritdoc IKrStaking
    function massUpdatePools() public payable {
        for (uint256 pid; pid < _poolInfo.length; ++pid) {
            updatePool(pid);
        }
    }

    /// @inheritdoc IKrStaking
    function updatePool(uint256 _pid) public payable returns (PoolInfo memory pool) {
        pool = _poolInfo[_pid];
        // Updates once per block
        if (block.number > pool.lastRewardBlock) {
            uint256 deposits = pool.depositToken.balanceOf(address(this));
            // No rewards for 0 deposits
            if (deposits > 0) {
                for (uint256 rewardIndex; rewardIndex < pool.rewardTokens.length; rewardIndex++) {
                    // Reward per block for a particular reward token
                    uint256 rewardPerBlock = rewardPerBlockFor[pool.rewardTokens[rewardIndex]];
                    // Blocks advanced since last update
                    uint256 blocks = block.number - pool.lastRewardBlock;
                    // Allocation for this particular pool
                    uint256 reward = (rewardPerBlock * blocks * pool.allocPoint) / totalAllocPoint;
                    // Increment accumulated rewards for new block height
                    pool.accRewardPerShares[rewardIndex] += (reward * 1e12) / deposits;
                }
            }
            // No further updates within same block height
            pool.lastRewardBlock = uint128(block.number);
            // storage
            _poolInfo[_pid] = pool;
        }
    }

    /// @inheritdoc IKrStaking
    function deposit(address _to, uint256 _pid, uint256 _amount) external payable nonReentrant ensurePoolExists(_pid) {
        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = _userInfo[_pid][_to];

        // Initialize rewardDebts
        if (user.rewardDebts.length == 0) {
            user.rewardDebts = new uint256[](pool.rewardTokens.length);
        }

        pool.depositToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        user.amount += _amount;

        for (uint256 rewardIndex; rewardIndex < pool.rewardTokens.length; rewardIndex++) {
            user.rewardDebts[rewardIndex] += (_amount * pool.accRewardPerShares[rewardIndex]) / 1e12;
        }

        emit Deposit(_to, _pid, _amount);
    }

    /// @inheritdoc IKrStaking
    function withdraw(uint256 _pid, uint256 _amount, address _rewardRecipient) external payable nonReentrant {
        require(_amount > 0, "KR: 0-withdraw");
        require(_rewardRecipient != address(0), "KR: !rewardRecipient");

        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = _userInfo[_pid][msg.sender];

        sendRewards(pool, user, _rewardRecipient);

        // Send whole balance in case of amount exceeds deposits
        if (_amount > user.amount) {
            _amount = user.amount;
            user.amount = 0;
        } else {
            user.amount -= _amount;
        }

        pool.depositToken.safeTransfer(address(msg.sender), _amount);

        for (uint256 rewardIndex; rewardIndex < pool.rewardTokens.length; rewardIndex++) {
            user.rewardDebts[rewardIndex] = (user.amount * pool.accRewardPerShares[rewardIndex]) / 1e12;
        }

        emit Withdraw(msg.sender, _pid, _amount);
    }

    /// @inheritdoc IKrStaking
    function claim(uint256 _pid, address _rewardRecipient) external payable nonReentrant {
        require(_rewardRecipient != address(0), "KR: !rewardRecipient");

        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = _userInfo[_pid][msg.sender];

        if (user.amount > 0) {
            sendRewards(pool, user, _rewardRecipient);

            for (uint256 rewardIndex; rewardIndex < pool.rewardTokens.length; rewardIndex++) {
                user.rewardDebts[rewardIndex] = (user.amount * pool.accRewardPerShares[rewardIndex]) / 1e12;
            }
        }
    }

    /// @inheritdoc IKrStaking
    function emergencyWithdraw(uint256 _pid) external payable nonReentrant {
        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = _userInfo[_pid][msg.sender];
        pool.depositToken.safeTransfer(address(msg.sender), user.amount);
        user.amount = 0;
        for (uint256 rewardIndex; rewardIndex < pool.rewardTokens.length; rewardIndex++) {
            user.rewardDebts[rewardIndex] = 0;
        }
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    }

    /**
     * ==================================================
     * ============= Admin functions ====================
     * ==================================================
     */

    /// @inheritdoc IKrStaking
    function setRewardPerBlockFor(
        address _rewardToken,
        uint256 _rewardPerBlock
    ) external payable onlyRole(OPERATOR_ROLE) {
        rewardPerBlockFor[_rewardToken] = _rewardPerBlock;
    }

    /// @inheritdoc IKrStaking
    function addPool(
        address[] calldata _rewardTokens,
        IERC20 _depositToken,
        uint128 _allocPoint,
        uint128 _startBlock
    ) external payable onlyRole(OPERATOR_ROLE) ensurePoolDoesNotExist(_depositToken) {
        require(_rewardTokens.length > 0, "KR: !rewardTokens");

        totalAllocPoint += _allocPoint;

        _poolInfo.push(
            PoolInfo({
                depositToken: _depositToken,
                allocPoint: _allocPoint,
                lastRewardBlock: _startBlock != 0 ? _startBlock : uint128(block.number),
                accRewardPerShares: new uint256[](_rewardTokens.length),
                rewardTokens: _rewardTokens
            })
        );
    }

    /// @inheritdoc IKrStaking
    function setPool(
        uint256 _pid,
        uint128 _newAllocPoint
    ) external payable onlyRole(OPERATOR_ROLE) ensurePoolExists(_pid) {
        totalAllocPoint -= _poolInfo[_pid].allocPoint + _newAllocPoint;
        _poolInfo[_pid].allocPoint = _newAllocPoint;
    }

    /**
     * ==================================================
     * ============ Protected functions =================
     * ==================================================
     */

    /// @inheritdoc IKrStaking
    function withdrawFor(
        address _for,
        uint256 _pid,
        uint256 _amount,
        address _rewardRecipient
    ) external payable nonReentrant onlyRole(OPERATOR_ROLE) {
        require(_amount > 0, "KR: 0-withdraw");
        require(_rewardRecipient != address(0), "KR: !rewardRecipient");

        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = _userInfo[_pid][_for];

        sendRewards(pool, user, _rewardRecipient);

        // Send whole balance in case of amount exceeds deposits
        if (_amount > user.amount) {
            _amount = user.amount;
            user.amount = 0;
        } else {
            user.amount -= _amount;
        }

        pool.depositToken.safeTransfer(address(msg.sender), _amount);

        for (uint256 rewardIndex; rewardIndex < pool.rewardTokens.length; rewardIndex++) {
            user.rewardDebts[rewardIndex] = (user.amount * pool.accRewardPerShares[rewardIndex]) / 1e12;
        }

        emit Withdraw(_for, _pid, _amount);
    }

    /// @inheritdoc IKrStaking
    function claimFor(
        address _for,
        uint256 _pid,
        address _rewardRecipient
    ) external payable nonReentrant onlyRole(OPERATOR_ROLE) {
        require(_rewardRecipient != address(0), "KR: !rewardRecipient");

        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = _userInfo[_pid][_for];

        if (user.amount > 0) {
            sendRewards(pool, user, _rewardRecipient);

            for (uint256 rewardIndex; rewardIndex < pool.rewardTokens.length; rewardIndex++) {
                user.rewardDebts[rewardIndex] = (user.amount * pool.accRewardPerShares[rewardIndex]) / 1e12;
            }
        }
    }

    /// @inheritdoc IKrStaking
    function rescueNative() external payable onlyRole(OPERATOR_ROLE) {
        payable(msg.sender).transfer(address(this).balance);
    }

    /// @inheritdoc IKrStaking
    function rescueNonPoolToken(
        IERC20 _tokenToRescue,
        uint256 _amount
    ) external payable onlyRole(OPERATOR_ROLE) ensurePoolDoesNotExist(_tokenToRescue) {
        _tokenToRescue.safeTransfer(msg.sender, _amount);
    }

    /**
     * ==================================================
     * ============= Internal functions =================
     * ==================================================
     */

    /**
     * @notice Loops over pools reward tokens and sends them to the user
     * @param pool pool to send rewards from in `_poolInfo`
     * @param user users info in the @param pool
     * @param recipient user to send rewards to
     */
    function sendRewards(PoolInfo memory pool, UserInfo memory user, address recipient) internal {
        for (uint256 rewardIndex; rewardIndex < pool.rewardTokens.length; rewardIndex++) {
            uint256 rewardDebt = (user.amount * pool.accRewardPerShares[rewardIndex]) / 1e12;
            uint256 pending = rewardDebt - user.rewardDebts[rewardIndex];

            if (pending > 0) {
                IERC20(pool.rewardTokens[rewardIndex]).safeTransfer(recipient, pending);
                emit ClaimRewards(recipient, pool.rewardTokens[rewardIndex], pending);
            }
        }
    }
}
