// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {SD59x18, sd, unwrap, exp, UNIT, ZERO} from "@prb/math/src/SD59x18.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Types.sol";
import "./interfaces/IVStaker.sol";
import "./interfaces/IVChainMinter.sol";
import "./interfaces/IVTokenomicsParams.sol";
import "./external/interfaces/IvPair.sol";
import "./external/interfaces/IvPairFactory.sol";

contract VStaker is IVStaker {
    // approximately 3 years limit
    uint256 public constant LOCK_DURATION_LIMIT = 3 * 12 * 4 weeks;
    // 1 staking positions for unlocked VRSW + 20 for locked VRSW
    uint256 public constant STAKE_POSITIONS_LIMIT = 21;

    /**
     * @dev The amount of LP tokens staked by each user.
     * [wallet]
     */
    mapping(address => LpStake[]) public lpStakes;

    /**
     * @dev The index in lpStakes array of [wallet][lpToken]
     */
    mapping(address => mapping(address => uint)) public lpStakeIndex;

    /**
     * @dev The mu value of each user's LP stake. You can learn more about mu and
     * staking formula in Virtuswap Tokenomics Whitepaper.
     * [wallet][lpToken]
     */
    mapping(address => mapping(address => SD59x18)) public mu;

    /**
     * @dev Accrued rewards currently available for user to withdraw for staking
     * specified lpToken.
     * [wallet][lpToken][rewardToken]
     */
    mapping(address => mapping(address => mapping(address => SD59x18)))
        public rewards;

    /**
     * @dev The snapshot of extraRewardsCoefficintGlobal at the time of the last update.
     * [wallet][lpToken][rewardToken]
     */
    mapping(address => mapping(address => mapping(address => SD59x18)))
        public extraRewardsCoefficient;

    /**
     * @dev The snapshot of baseRewardsCoefficintGlobal at the time of the last update.
     * [wallet][lpToken][rewardToken]
     */
    mapping(address => mapping(address => mapping(address => SD59x18)))
        public baseRewardsCoefficient;

    /**
     * @dev The VRSW stakes of each user.
     * [wallet]
     */
    mapping(address => VrswStake[]) public vrswStakes;

    /**
     * @dev Sum of all user's mu values for a specified lpToken.
     * [lpToken]
     */
    mapping(address => SD59x18) public totalMu;

    /**
     * @dev Sum of all user's lp tokens staked for a specified pool.
     * [pool]
     */
    mapping(address => SD59x18) public totalLpStaked;

    /**
     * @dev Coefficient needed to calculate accrued rewards. It's equal to:
     * SUM(vrswEmission(t_{i - 1}, t_{i}) / totalMu(t_i)), where t_i is the
     * timestamp when totalMu has changed.
     * [lpToken][rewardToken]
     */
    mapping(address => mapping(address => SD59x18))
        public extraRewardsCoefficientGlobal;

    /**
     * @dev Coefficient needed to calculate accrued rewards. It's equal to:
     * SUM(vrswEmission(t_{i - 1}, t_{i}) / totalLpStaked(t_i)), where t_i is the
     * timestamp when totalMu has changed.
     * [lpToken][rewardToken]
     */
    mapping(address => mapping(address => SD59x18))
        public baseRewardsCoefficientGlobal;

    /**
     * @dev The total amount of reward tokens available for distribution
     * for staking specified lpToken.
     * [lpToken][rewardToken]
     */
    mapping(address => mapping(address => SD59x18))
        public totalExtraRewardTokensAvailable;

    /**
     * @dev The total amount of reward tokens available for distribution
     * for staking specified lpToken.
     * [lpToken][rewardToken]
     */
    mapping(address => mapping(address => SD59x18))
        public totalBaseRewardTokensAvailable;

    // Virtuswap pair factory address
    address public immutable vPairFactory;

    // minter address
    address public immutable minter;

    // VRSW token address
    address public immutable vrswToken;

    // tokenomics params address
    address public immutable tokenomicsParams;

    // start of VRSW emission in seconds
    uint256 public immutable emissionStartTs;

    address public immutable oldStaker;

    mapping(address => uint256) public positionMigrationCounter;

    modifier notBefore(uint256 timestamp) {
        require(block.timestamp >= timestamp, "too early");
        _;
    }

    modifier validLockDuration(uint128 lockDuration) {
        require(
            lockDuration > 0 && lockDuration <= LOCK_DURATION_LIMIT,
            "insufficient lock duration"
        );
        _;
    }

    modifier positiveAmount(uint256 amount) {
        require(amount > 0, "insufficient amount");
        _;
    }

    modifier validPool(address pool) {
        require(isPoolValid(pool), "invalid lp token");
        _;
    }

    constructor(
        address _vrswToken,
        address _minter,
        address _tokenomicsParams,
        address _vPairFactory,
        address _oldStaker
    ) {
        oldStaker = _oldStaker;
        minter = _minter;
        vrswToken = _vrswToken;
        tokenomicsParams = _tokenomicsParams;
        emissionStartTs = IVChainMinter(minter).emissionStartTs();
        vPairFactory = _vPairFactory;
    }

    /// @inheritdoc IVStaker
    function stakeVrsw(
        uint256 amount
    ) external override notBefore(emissionStartTs) positiveAmount(amount) {
        if (lpStakes[msg.sender].length == 0)
            lpStakes[msg.sender].push(LpStake(address(0), ZERO));

        _updateEveryStateBefore(msg.sender);
        VrswStake memory stake = _stakeUnlocked(msg.sender, amount);
        lpStakes[msg.sender][0].amount = lpStakes[msg.sender][0].amount.add(
            sd(int256(amount))
        );
        unchecked {
            totalLpStaked[address(0)] = totalLpStaked[address(0)].add(
                sd(int256(amount))
            );
        }
        _updateEveryStateAfter(msg.sender);

        SafeERC20.safeTransferFrom(
            IERC20(vrswToken),
            msg.sender,
            address(this),
            amount
        );
        IVChainMinter(minter).mintVeVrsw(msg.sender, amount);
        emit StakeVrsw(
            msg.sender,
            amount,
            stake.startTs,
            uint256(unwrap(stake.discountFactor))
        );
    }

    /// @inheritdoc IVStaker
    function stakeLp(
        address lpToken,
        uint256 amount
    )
        external
        override
        notBefore(emissionStartTs)
        positiveAmount(amount)
        validPool(lpToken)
    {
        if (lpStakes[msg.sender].length == 0)
            lpStakes[msg.sender].push(LpStake(address(0), ZERO));

        _updateStateBefore(msg.sender, lpToken);
        uint lpStakeIdx = lpStakeIndex[msg.sender][lpToken];
        if (lpStakeIdx == 0) {
            lpStakes[msg.sender].push(LpStake(lpToken, sd(int256(amount))));
            lpStakeIndex[msg.sender][lpToken] = lpStakes[msg.sender].length - 1;
        } else {
            lpStakes[msg.sender][lpStakeIdx].amount = lpStakes[msg.sender][
                lpStakeIdx
            ].amount.add(sd(int256(amount)));
        }
        unchecked {
            totalLpStaked[lpToken] = totalLpStaked[lpToken].add(
                sd(int256(amount))
            );
        }
        _updateStateAfter(msg.sender, lpToken);

        SafeERC20.safeTransferFrom(
            IERC20(lpToken),
            msg.sender,
            address(this),
            amount
        );
        emit StakeLp(msg.sender, lpToken, amount);
    }

    /// @inheritdoc IVStaker
    function claimRewards(
        address lpToken
    ) external override notBefore(emissionStartTs) {
        _updateStateBefore(msg.sender, lpToken);

        address[] memory rewardTokens = IVChainMinter(minter).getRewardTokens(
            lpToken
        );
        uint[] memory amounts = new uint[](rewardTokens.length);
        for (uint i = 0; i < rewardTokens.length; ++i) {
            amounts[i] = _calculateAccruedRewards(
                msg.sender,
                lpToken,
                rewardTokens[i],
                true
            );
            rewards[msg.sender][lpToken][rewardTokens[i]] = ZERO;
        }
        IVChainMinter(minter).transferRewards(
            msg.sender,
            lpToken,
            rewardTokens,
            amounts
        );
    }

    /// @inheritdoc IVStaker
    function unstakeLp(
        address lpToken,
        uint256 amount
    )
        external
        override
        notBefore(emissionStartTs)
        positiveAmount(amount)
        validPool(lpToken)
    {
        uint lpStakeIdx = lpStakeIndex[msg.sender][lpToken];
        SD59x18 currentAmount = lpStakes[msg.sender][lpStakeIdx].amount;
        require(lpStakeIdx != 0, "no such stake");
        require(amount <= uint256(unwrap(currentAmount)), "not enough tokens");

        _updateStateBefore(msg.sender, lpToken);
        SD59x18 newAmount = currentAmount.sub(sd(int256(amount)));
        lpStakes[msg.sender][lpStakeIdx].amount = newAmount;
        unchecked {
            totalLpStaked[lpToken] = totalLpStaked[lpToken].sub(
                sd(int256(amount))
            );
        }
        _updateStateAfter(msg.sender, lpToken);

        if (unwrap(newAmount) == 0) {
            lpStakes[msg.sender][lpStakeIdx] = lpStakes[msg.sender][
                lpStakes[msg.sender].length - 1
            ];
            lpStakeIndex[msg.sender][
                lpStakes[msg.sender][lpStakeIdx].lpToken
            ] = lpStakeIdx;
            delete lpStakeIndex[msg.sender][lpToken];
            lpStakes[msg.sender].pop();
        }

        SafeERC20.safeTransfer(IERC20(lpToken), msg.sender, amount);

        emit UnstakeLp(msg.sender, lpToken, amount);
    }

    /// @inheritdoc IVStaker
    function unstakeVrsw(
        uint256 amount
    ) external override notBefore(emissionStartTs) positiveAmount(amount) {
        VrswStake[] storage senderStakes = vrswStakes[msg.sender];
        require(senderStakes.length > 0, "no stakes");
        require(
            amount <= uint256(unwrap(senderStakes[0].amount)),
            "not enough tokens"
        );

        _updateEveryStateBefore(msg.sender);
        senderStakes[0].amount = senderStakes[0].amount.sub(sd(int256(amount)));
        lpStakes[msg.sender][0].amount = lpStakes[msg.sender][0].amount.sub(
            sd(int256(amount))
        );
        unchecked {
            totalLpStaked[address(0)] = totalLpStaked[address(0)].sub(
                sd(int256(amount))
            );
        }
        _updateEveryStateAfter(msg.sender);

        SafeERC20.safeTransfer(IERC20(vrswToken), msg.sender, amount);
        IVChainMinter(minter).burnVeVrsw(msg.sender, amount);

        emit UnstakeVrsw(msg.sender, amount);
    }

    /// @inheritdoc IVStaker
    function lockVrsw(
        uint256 amount,
        uint128 lockDuration
    )
        external
        override
        notBefore(emissionStartTs)
        validLockDuration(lockDuration)
        positiveAmount(amount)
    {
        VrswStake[] storage senderStakes = vrswStakes[msg.sender];
        require(
            senderStakes.length <= STAKE_POSITIONS_LIMIT,
            "stake positions limit is exceeded"
        );
        if (senderStakes.length == 0) {
            senderStakes.push(VrswStake(0, 0, ZERO, ZERO));
        }
        if (lpStakes[msg.sender].length == 0)
            lpStakes[msg.sender].push(LpStake(address(0), ZERO));

        _updateEveryStateBefore(msg.sender);
        lpStakes[msg.sender][0].amount = lpStakes[msg.sender][0].amount.add(
            sd(int256(amount))
        );
        VrswStake memory stake = _newStakePosition(amount, lockDuration);
        unchecked {
            totalLpStaked[address(0)] = totalLpStaked[address(0)].add(
                sd(int256(amount))
            );
        }
        _updateEveryStateAfter(msg.sender);

        SafeERC20.safeTransferFrom(
            IERC20(vrswToken),
            msg.sender,
            address(this),
            amount
        );
        IVChainMinter(minter).mintVeVrsw(msg.sender, amount);
        emit LockVrsw(
            msg.sender,
            amount,
            lockDuration,
            stake.startTs,
            uint256(unwrap(stake.discountFactor))
        );
    }

    /// @inheritdoc IVStaker
    function lockStakedVrsw(
        uint256 amount,
        uint128 lockDuration
    )
        external
        override
        notBefore(emissionStartTs)
        validLockDuration(lockDuration)
        positiveAmount(amount)
    {
        VrswStake[] storage senderStakes = vrswStakes[msg.sender];
        require(senderStakes.length > 0, "no stakes");
        require(
            senderStakes.length <= STAKE_POSITIONS_LIMIT,
            "stake positions limit is exceeded"
        );
        require(
            amount <= uint256(unwrap(senderStakes[0].amount)),
            "not enough tokens"
        );

        _updateEveryStateBefore(msg.sender);
        senderStakes[0].amount = senderStakes[0].amount.sub(sd(int256(amount)));
        VrswStake memory stake = _newStakePosition(amount, lockDuration);
        _updateEveryStateAfter(msg.sender);
        emit LockStakedVrsw(
            msg.sender,
            amount,
            lockDuration,
            stake.startTs,
            uint256(unwrap(stake.discountFactor))
        );
    }

    /// @inheritdoc IVStaker
    function unlockVrsw(
        address who,
        uint256 position
    ) external override notBefore(emissionStartTs) {
        uint userStakesNumber = vrswStakes[who].length;
        require(who != address(0), "zero address");
        require(
            position > 0 && position < userStakesNumber,
            "invalid position"
        );

        VrswStake memory userStake = vrswStakes[who][position];
        require(
            userStake.startTs + userStake.lockDuration <= block.timestamp,
            "locked"
        );

        uint256 vrswToUnlock = uint256(unwrap(userStake.amount));

        _updateEveryStateBefore(who);
        vrswStakes[who][position] = vrswStakes[who][userStakesNumber - 1];
        vrswStakes[who].pop();
        _stakeUnlocked(who, vrswToUnlock);
        _updateEveryStateAfter(who);

        emit UnlockVrsw(who, vrswToUnlock);
    }

    /// @inheritdoc IVStaker
    function checkLock(
        address who
    ) external view override returns (uint[] memory unlockedPositions) {
        VrswStake[] storage userStakes = vrswStakes[who];
        uint256 stakesLength = userStakes.length;
        uint256 unlockedPositionsNumber;
        for (uint256 i = 1; i < stakesLength; ++i) {
            if (
                userStakes[i].startTs + userStakes[i].lockDuration <=
                block.timestamp
            ) {
                ++unlockedPositionsNumber;
            }
        }
        unlockedPositions = new uint[](unlockedPositionsNumber);
        for (uint256 i = 1; i < stakesLength; ++i) {
            if (
                userStakes[i].startTs + userStakes[i].lockDuration <=
                block.timestamp
            ) {
                unlockedPositions[--unlockedPositionsNumber] = i;
            }
        }
    }

    /// @inheritdoc IVStaker
    function viewRewards(
        address who,
        address lpToken,
        address rewardToken
    ) external view override returns (uint256) {
        return _calculateAccruedRewards(who, lpToken, rewardToken, false);
    }

    /// @inheritdoc IVStaker
    function viewVrswStakes()
        external
        view
        override
        returns (VrswStake[] memory _vrswStakes)
    {
        _vrswStakes = vrswStakes[msg.sender];
    }

    /// @inheritdoc IVStaker
    function viewLpStakes()
        external
        view
        override
        returns (LpStake[] memory _lpStakes)
    {
        _lpStakes = lpStakes[msg.sender];
    }

    /// @inheritdoc IVStaker
    function triggerStateUpdateBefore(
        address[] calldata wallets
    ) public override {
        for (uint i = 0; i < wallets.length; ++i) {
            _updateEveryStateBefore(wallets[i]);
        }
    }

    /// @inheritdoc IVStaker
    function triggerStateUpdateAfter(
        address[] calldata wallets
    ) public override {
        for (uint i = 0; i < wallets.length; ++i) {
            _updateEveryStateAfter(wallets[i]);
        }
    }

    /// @inheritdoc IVStaker
    function isPoolValid(address pool) public view override returns (bool) {
        (address token0, address token1) = IvPair(pool).getTokens();
        return IvPairFactory(vPairFactory).pairs(token0, token1) == pool;
    }

    /**
     * @dev Adds a new stake position for the staker
     * @param amount Amount of VRSW tokens to stake
     * @param lockDuration Duration of the lock period for the stake
     */
    function _newStakePosition(
        uint256 amount,
        uint128 lockDuration
    ) private returns (VrswStake memory stake) {
        VrswStake[] storage senderStakes = vrswStakes[msg.sender];
        stake = VrswStake(
            uint128(block.timestamp),
            lockDuration,
            _calculateDiscountFactor(senderStakes.length),
            sd(int256(amount))
        );
        senderStakes.push(stake);
    }

    /**
     * @dev Stakes VRSW after the lock has expired
     * @param who The staker address
     * @param amount Amount of VRSW tokens to stake
     */
    function _stakeUnlocked(
        address who,
        uint256 amount
    ) private returns (VrswStake memory) {
        VrswStake[] storage senderStakes = vrswStakes[who];

        if (senderStakes.length == 0) {
            senderStakes.push(VrswStake(0, 0, ZERO, ZERO));
        }

        VrswStake memory oldStake = senderStakes[0];

        // discount factor here is calculated considering old discount factor such that
        // it satisfies equation: (a1 + a2) * f2 = (a1 * exp(-rt1) + a2 * exp(-rt2))
        // where a1 - the amount that was already staked,
        //       a2 - the amount that is staking,
        //       f1 - old discount factor,
        //       f2 - new discount factor,
        //       r  - tokenomics param,
        //       t1, t2 - the timestamps of old stake and new stake respectively
        senderStakes[0] = VrswStake(
            uint128(block.timestamp),
            0,
            oldStake
                .amount
                .mul(oldStake.discountFactor)
                .add(sd(int256(amount)).mul(_calculateDiscountFactor(0)))
                .div(oldStake.amount.add(sd(int256(amount)))),
            oldStake.amount.add(sd(int256(amount)))
        );

        return senderStakes[0];
    }

    /**
     * @dev Updates every user's state of all staked lpTokens before the update
     * @param who The user's address
     */
    function _updateEveryStateBefore(address who) private {
        uint lpStakesNumber = lpStakes[who].length;
        for (uint i = 0; i < lpStakesNumber; ++i) {
            _updateStateBefore(who, lpStakes[who][i].lpToken);
        }
    }

    /**
     * @dev Updates every user's state of all staked lpTokens after the update
     * @param who The user's address
     */
    function _updateEveryStateAfter(address who) private {
        SD59x18 vrswMultiplier = _calculateVrswMultiplier(who);
        SD59x18 newMu;
        SD59x18 newTotalMu;
        uint lpStakesNumber = lpStakes[who].length;
        address lpToken;
        for (uint i = 0; i < lpStakesNumber; ++i) {
            lpToken = lpStakes[who][i].lpToken;
            (newMu, newTotalMu) = _calculateStateAfter(
                who,
                lpToken,
                vrswMultiplier
            );
            (mu[who][lpToken], totalMu[lpToken]) = (newMu, newTotalMu);
            emit MuChanged(
                who,
                lpToken,
                uint256(unwrap(newMu)),
                uint256(unwrap(newTotalMu))
            );
        }
    }

    /**
     * @dev Updates the state of the user before the update
     * @param who The user's address
     */
    function _updateStateBefore(address who, address lpToken) private {
        address[] memory rewardTokens = IVChainMinter(minter).getRewardTokens(
            lpToken
        );
        for (uint i = 0; i < rewardTokens.length; ++i) {
            (
                totalExtraRewardTokensAvailable[lpToken][rewardTokens[i]],
                totalBaseRewardTokensAvailable[lpToken][rewardTokens[i]],
                extraRewardsCoefficient[who][lpToken][rewardTokens[i]],
                extraRewardsCoefficientGlobal[lpToken][rewardTokens[i]],
                baseRewardsCoefficient[who][lpToken][rewardTokens[i]],
                baseRewardsCoefficientGlobal[lpToken][rewardTokens[i]],
                rewards[who][lpToken][rewardTokens[i]]
            ) = _calculateStateBefore(who, lpToken, rewardTokens[i]);
        }
    }

    /**
     * @dev Updates the state of the user after the update
     * @param who The user's address
     */
    function _updateStateAfter(address who, address lpToken) private {
        SD59x18 vrswMultiplier = _calculateVrswMultiplier(who);
        (SD59x18 newMu, SD59x18 newTotalMu) = _calculateStateAfter(
            who,
            lpToken,
            vrswMultiplier
        );
        (mu[who][lpToken], totalMu[lpToken]) = (newMu, newTotalMu);
        emit MuChanged(
            who,
            lpToken,
            uint256(unwrap(newMu)),
            uint256(unwrap(newTotalMu))
        );
    }

    /**
     * @dev Calculates the accrued rewards for the user
     * @param who The user's address
     * @param isStateChanged Whether the global state was changed before this function call
     * @return The amount of accrued rewards
     */
    function _calculateAccruedRewards(
        address who,
        address lpToken,
        address rewardToken,
        bool isStateChanged
    ) private view returns (uint256) {
        (, , , , , , SD59x18 _senderRewards) = isStateChanged
            ? (
                ZERO,
                ZERO,
                ZERO,
                ZERO,
                ZERO,
                ZERO,
                rewards[who][lpToken][rewardToken]
            )
            : _calculateStateBefore(who, lpToken, rewardToken);
        return uint256(unwrap(_senderRewards));
    }

    /**
     * @dev Calculates the state of the user before the update
     * @param lpToken The staked lpToken address
     * @param who The staker address
     */
    function _calculateStateBefore(
        address who,
        address lpToken,
        address rewardToken
    )
        private
        view
        returns (
            SD59x18 _totalExtraRewardTokensAvailable,
            SD59x18 _totalBaseRewardTokensAvailable,
            SD59x18 _senderExtraRewardsCoefficient,
            SD59x18 _extraRewardsCoefficientGlobal,
            SD59x18 _senderBaseRewardsCoefficient,
            SD59x18 _baseRewardsCoefficientGlobal,
            SD59x18 _senderRewards
        )
    {
        _senderRewards = rewards[who][lpToken][rewardToken];

        SD59x18 _totalRewardTokensAvailable = sd(
            int256(
                uint256(
                    IVChainMinter(minter).calculateTokensForPool(
                        lpToken,
                        rewardToken
                    )
                )
            )
        );

        SD59x18 lpBaseRewardsShare = IVTokenomicsParams(tokenomicsParams)
            .lpBaseRewardsShare();
        SD59x18 lpBaseRewardsShareFactor = IVTokenomicsParams(tokenomicsParams)
            .lpBaseRewardsShareFactor();

        if (unwrap(totalMu[lpToken]) != 0) {
            SD59x18 rewardTokensDiff = _totalRewardTokensAvailable.sub(
                totalExtraRewardTokensAvailable[lpToken][rewardToken]
            );
            SD59x18 extraRewards = rewardTokensDiff
                .mul(lpBaseRewardsShareFactor.sub(lpBaseRewardsShare))
                .div(lpBaseRewardsShareFactor);
            _totalExtraRewardTokensAvailable = _totalRewardTokensAvailable;
            _extraRewardsCoefficientGlobal = extraRewardsCoefficientGlobal[
                lpToken
            ][rewardToken].add(extraRewards.div(totalMu[lpToken]));
            _senderExtraRewardsCoefficient = _extraRewardsCoefficientGlobal;
            // you can learn more about the formula in Virtuswap Tokenomics Whitepaper
            _senderRewards = _senderRewards.add(
                mu[who][lpToken].mul(
                    _extraRewardsCoefficientGlobal.sub(
                        extraRewardsCoefficient[who][lpToken][rewardToken]
                    )
                )
            );
        } else {
            (
                _totalExtraRewardTokensAvailable,
                _senderExtraRewardsCoefficient,
                _extraRewardsCoefficientGlobal
            ) = (
                totalExtraRewardTokensAvailable[lpToken][rewardToken],
                extraRewardsCoefficient[who][lpToken][rewardToken],
                extraRewardsCoefficientGlobal[lpToken][rewardToken]
            );
        }
        if (unwrap(totalLpStaked[lpToken]) != 0) {
            SD59x18 rewardTokensDiff = _totalRewardTokensAvailable.sub(
                totalBaseRewardTokensAvailable[lpToken][rewardToken]
            );
            SD59x18 baseRewards = rewardTokensDiff.mul(lpBaseRewardsShare).div(
                lpBaseRewardsShareFactor
            );
            _totalBaseRewardTokensAvailable = _totalRewardTokensAvailable;
            _baseRewardsCoefficientGlobal = baseRewardsCoefficientGlobal[
                lpToken
            ][rewardToken].add(baseRewards.div(totalLpStaked[lpToken]));
            _senderBaseRewardsCoefficient = _baseRewardsCoefficientGlobal;
            if (
                (lpToken == address(0) || lpStakeIndex[who][lpToken] != 0) &&
                lpStakes[who].length > 0
            ) {
                _senderRewards = _senderRewards.add(
                    lpStakes[who][lpStakeIndex[who][lpToken]].amount.mul(
                        _baseRewardsCoefficientGlobal.sub(
                            baseRewardsCoefficient[who][lpToken][rewardToken]
                        )
                    )
                );
            }
        } else {
            (
                _totalBaseRewardTokensAvailable,
                _senderBaseRewardsCoefficient,
                _baseRewardsCoefficientGlobal
            ) = (
                totalBaseRewardTokensAvailable[lpToken][rewardToken],
                baseRewardsCoefficient[who][lpToken][rewardToken],
                baseRewardsCoefficientGlobal[lpToken][rewardToken]
            );
        }
    }

    /**
     * @dev Calculates VRSW multiplier of the user
     * @param who The staker address
     */
    function _calculateVrswMultiplier(
        address who
    ) private view returns (SD59x18 mult) {
        VrswStake[] storage senderStakes = vrswStakes[who];
        uint256 stakesLength = senderStakes.length;
        for (uint256 i = 0; i < stakesLength; ++i) {
            mult = mult.add(
                senderStakes[i].amount.mul(senderStakes[i].discountFactor).mul(
                    UNIT.add(
                        IVTokenomicsParams(tokenomicsParams).b().mul(
                            sd(
                                int256(uint256(senderStakes[i].lockDuration)) *
                                    1e18
                            ).pow(IVTokenomicsParams(tokenomicsParams).gamma())
                        )
                    )
                )
            );
        }
    }

    /**
     * @dev Calculates the state of the user before the update
     * @param lpToken The staked lpToken address
     * @param who The staker address
     * @param vrswMultiplier The VRSW multiplier
     */
    function _calculateStateAfter(
        address who,
        address lpToken,
        SD59x18 vrswMultiplier
    ) private view returns (SD59x18 _mu, SD59x18 _totalMu) {
        _mu = lpStakes[who][lpStakeIndex[who][lpToken]]
            .amount
            .pow(IVTokenomicsParams(tokenomicsParams).alpha())
            .mul(
                vrswMultiplier.pow(IVTokenomicsParams(tokenomicsParams).beta())
            );
        unchecked {
            _totalMu = totalMu[lpToken].add(_mu.sub(mu[who][lpToken]));
        }
    }

    function _calculateDiscountFactor(
        uint256 position
    ) private returns (SD59x18) {
        if (position == 0 || positionMigrationCounter[msg.sender] < position) {
            (bool success, bytes memory result) = oldStaker.staticcall(
                abi.encodeWithSignature(
                    "vrswStakes(address,uint256)",
                    msg.sender,
                    position
                )
            );
            if (success) {
                VrswStake memory oldVrswStake = abi.decode(result, (VrswStake));
                if (position > 0) {
                    ++positionMigrationCounter[msg.sender];
                    return oldVrswStake.discountFactor;
                } else if (
                    unwrap(oldVrswStake.amount) > 0 &&
                    unwrap(vrswStakes[msg.sender][0].discountFactor) == 0
                ) {
                    return oldVrswStake.discountFactor;
                }
            }
        }
        return
            exp(
                IVTokenomicsParams(tokenomicsParams).r().mul(
                    sd(-int256(block.timestamp - emissionStartTs) * 1e18)
                )
            );
    }
}
