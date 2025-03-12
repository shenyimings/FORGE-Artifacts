// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./StakingInterface.sol";
import "./StakingVote.sol";
import "./StakingDestinations.sol";
import "../util/TransferETH.sol";
import "../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../../node_modules/@openzeppelin/contracts/utils/SafeCast.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Staking is
    StakingInterface,
    ReentrancyGuard,
    StakingVote,
    StakingDestinations,
    TransferETH
{
    using SafeMath for uint256;
    using SafeMath for uint128;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    /* ========== CONSTANT VARIABLES ========== */

    address internal constant ETH_ADDRESS = address(0);
    uint256 internal constant MAX_TERM = 1000;

    IERC20 internal immutable _stakingToken;
    uint256 internal immutable _startTimestamp; // timestamp of the term 0
    uint256 internal immutable _termInterval; // time interval between terms in second

    /* ========== STATE VARIABLES ========== */

    struct AccountInfo {
        uint128 stakeAmount; // active stake amount of the user at userTerm
        uint128 added; // the added amount of stake which will be merged to stakeAmount at the term+1.
        uint256 userTerm; // the term when the user executed any function last time (all the terms before the term has been already settled)
        uint256 rewards; // the total amount of rewards until userTerm
    }

    /**
     * @dev token => account => data
     */
    mapping(address => mapping(address => AccountInfo)) internal _accountInfo;

    struct TermInfo {
        uint128 stakeAdd; // the total added amount of stake which will be merged to stakeSum at the term+1
        uint128 stakeSum; // the total staking amount at the term
        uint256 rewardSum; // the total amount of rewards at the term
    }

    /**
     * @dev token => term => data
     */
    mapping(address => mapping(uint256 => TermInfo)) internal _termInfo;

    mapping(address => uint256) internal _currentTerm; // (token => term); the current term (all the info prior to this term is fixed)
    mapping(address => uint256) internal _totalRemainingRewards; // (token => amount); total unsettled amount of rewards

    /* ========== EVENTS ========== */

    event RewardAdded(address indexed token, uint256 reward);
    event Staked(address indexed token, address indexed account, uint128 amount);
    event Withdrawn(address indexed token, address indexed account, uint128 amount);
    event RewardPaid(address indexed token, address indexed account, uint256 reward);

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address stakingTokenAddress,
        address governance,
        uint256 startTimestamp,
        uint256 termInterval
    ) StakingVote(governance) {
        require(startTimestamp <= block.timestamp, "startTimestamp should be past time");
        _stakingToken = IERC20(stakingTokenAddress);
        _startTimestamp = startTimestamp;
        _termInterval = termInterval;
    }

    /* ========== MODIFIERS ========== */

    /**
     * @dev Calc total rewards of the account until the current term.
     */
    modifier updateReward(address token, address account) {
        AccountInfo memory accountInfo = _accountInfo[token][account];
        uint256 startTerm = accountInfo.userTerm;
        // When the loop count exceeds MAX_TERM, stop processing in order not to reach to the block gas limit
        for (
            uint256 term = accountInfo.userTerm;
            term < _currentTerm[token] && term < startTerm + MAX_TERM;
            term++
        ) {
            TermInfo memory termInfo = _termInfo[token][term];
            if (termInfo.stakeSum != 0) {
                accountInfo.rewards = accountInfo.rewards.add(
                    accountInfo.stakeAmount.mul(termInfo.rewardSum).div(termInfo.stakeSum)
                ); // `(your stake amount) / (total stake amount) * total rewards` in each term
            }
            accountInfo.stakeAmount = accountInfo.stakeAmount.add(accountInfo.added).toUint128();
            accountInfo.added = 0;
            accountInfo.userTerm = term + 1; // calculated until this term
            if (accountInfo.stakeAmount == 0) {
                accountInfo.userTerm = _currentTerm[token];
                break; // skip unnecessary term
            }
        }
        _accountInfo[token][account] = accountInfo;
        _;
    }

    /**
     * @dev Update the info up to the current term.
     */
    modifier updateTerm(address token) {
        if (_currentTerm[token] < _getLatestTerm()) {
            uint256 currentBalance = (token == ETH_ADDRESS)
                ? address(this).balance
                : IERC20(token).balanceOf(address(this));
            uint256 nextRewardSum = currentBalance.sub(_totalRemainingRewards[token]);

            TermInfo memory currentTermInfo = _termInfo[token][_currentTerm[token]];
            uint128 nextStakeSum = currentTermInfo
                .stakeSum
                .add(currentTermInfo.stakeAdd)
                .toUint128();
            uint256 carriedReward = currentTermInfo.stakeSum == 0 ? currentTermInfo.rewardSum : 0; // if stakeSum is 0, carried forward until someone stakes
            uint256 nextTerm = nextStakeSum == 0 ? _getLatestTerm() : _currentTerm[token] + 1; // if next stakeSum is 0, skip to latest term
            _termInfo[token][nextTerm] = TermInfo({
                stakeAdd: 0,
                stakeSum: nextStakeSum,
                rewardSum: nextRewardSum.add(carriedReward)
            });

            // write total stake amount since (nextTerm + 1) until _getLatestTerm()
            if (nextTerm < _getLatestTerm()) {
                // assert(_termInfo[token][nextTerm].stakeSum != 0 && _termInfo[token][nextTerm].stakeAdd == 0);
                _termInfo[token][_getLatestTerm()] = TermInfo({
                    stakeAdd: 0,
                    stakeSum: nextStakeSum,
                    rewardSum: 0
                });
            }

            _totalRemainingRewards[token] = currentBalance; // total amount of unpaid reward
            _currentTerm[token] = _getLatestTerm();
        }
        _;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice Stake the staking token for the token to be paid as reward.
     */
    function stake(address token, uint128 amount)
        external
        override
        nonReentrant
        updateTerm(token)
        updateReward(token, msg.sender)
    {
        if (_accountInfo[token][msg.sender].userTerm < _currentTerm[token]) {
            return;
        }

        require(amount != 0, "staking amount should be positive number");

        _updVoteAdd(msg.sender, amount);
        _stake(msg.sender, token, amount);
        _stakingToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice Withdraw the staking token for the token to be paid as reward.
     */
    function withdraw(address token, uint128 amount)
        external
        override
        nonReentrant
        updateTerm(token)
        updateReward(token, msg.sender)
    {
        if (_accountInfo[token][msg.sender].userTerm < _currentTerm[token]) {
            return;
        }

        require(amount != 0, "withdrawing amount should be positive number");

        _updVoteSub(msg.sender, amount);
        _withdraw(msg.sender, token, amount);
        _stakingToken.safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Receive the reward for your staking in the token.
     */
    function receiveReward(address token)
        external
        override
        nonReentrant
        updateTerm(token)
        updateReward(token, msg.sender)
        returns (uint256 rewards)
    {
        rewards = _accountInfo[token][msg.sender].rewards;
        if (rewards != 0) {
            _totalRemainingRewards[token] = _totalRemainingRewards[token].sub(rewards); // subtract the total unpaid reward
            _accountInfo[token][msg.sender].rewards = 0;
            if (token == ETH_ADDRESS) {
                _transferETH(msg.sender, rewards);
            } else {
                IERC20(token).safeTransfer(msg.sender, rewards);
            }
            emit RewardPaid(token, msg.sender, rewards);
        }
    }

    function changeStakeTarget(
        address oldTarget,
        address newTarget,
        uint128 amount
    )
        external
        override
        nonReentrant
        updateTerm(oldTarget)
        updateReward(oldTarget, msg.sender)
        updateTerm(newTarget)
        updateReward(newTarget, msg.sender)
    {
        if (
            _accountInfo[oldTarget][msg.sender].userTerm < _currentTerm[oldTarget] ||
            _accountInfo[newTarget][msg.sender].userTerm < _currentTerm[newTarget]
        ) {
            return;
        }

        require(amount != 0, "transfering amount should be positive number");

        _withdraw(msg.sender, oldTarget, amount);
        _stake(msg.sender, newTarget, amount);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _stake(
        address account,
        address token,
        uint128 amount
    ) internal {
        AccountInfo memory accountInfo = _accountInfo[token][account];
        if (accountInfo.stakeAmount == 0 && accountInfo.added == 0) {
            _addDestinations(account, token);
        }

        _accountInfo[token][account].added = accountInfo.added.add(amount).toUint128(); // added when the term is shifted (the user)

        uint256 term = _currentTerm[token];
        _termInfo[token][term].stakeAdd = _termInfo[token][term].stakeAdd.add(amount).toUint128(); // added when the term is shifted (global)

        emit Staked(token, account, amount);
    }

    function _withdraw(
        address account,
        address token,
        uint128 amount
    ) internal {
        AccountInfo memory accountInfo = _accountInfo[token][account];
        require(
            accountInfo.stakeAmount.add(accountInfo.added) >= amount,
            "exceed withdrawable amount"
        );

        if (accountInfo.stakeAmount + accountInfo.added == amount) {
            _removeDestinations(account, token);
        }

        uint256 currentTerm = _currentTerm[token];
        TermInfo memory termInfo = _termInfo[token][currentTerm];
        if (accountInfo.added > amount) {
            accountInfo.added -= amount;
            termInfo.stakeAdd -= amount;
        } else {
            termInfo.stakeSum = termInfo.stakeSum.sub(amount - accountInfo.added).toUint128();
            termInfo.stakeAdd = termInfo.stakeAdd.sub(accountInfo.added).toUint128();
            accountInfo.stakeAmount = accountInfo
                .stakeAmount
                .sub(amount - accountInfo.added)
                .toUint128();
            accountInfo.added = 0;
        }

        _accountInfo[token][account] = accountInfo;
        _termInfo[token][currentTerm] = termInfo;

        emit Withdrawn(token, account, amount);
    }

    function _getNextTermReward(address token) internal view returns (uint256 rewards) {
        // as the term at current+1 has not been settled
        uint256 currentBalance = (token == ETH_ADDRESS)
            ? address(this).balance
            : IERC20(token).balanceOf(address(this));
        return
            (currentBalance > _totalRemainingRewards[token])
                ? currentBalance - _totalRemainingRewards[token]
                : 0;
    }

    function _getLatestTerm() internal view returns (uint256) {
        return (block.timestamp - _startTimestamp) / _termInterval;
    }

    /* ========== CALL FUNCTIONS ========== */

    /**
     * @return stakingTokenAddress is the token locked for staking
     */
    function getStakingTokenAddress() external view override returns (address stakingTokenAddress) {
        return address(_stakingToken);
    }

    /**
     * @return startTimestamp is the time when this contract was deployed
     * @return termInterval is the duration of a term
     */
    function getConfigs()
        external
        view
        override
        returns (uint256 startTimestamp, uint256 termInterval)
    {
        startTimestamp = _startTimestamp;
        termInterval = _termInterval;
    }

    /**
     * @return the ERC20 token addresses in staking
     */
    function getStakingDestinations(address account)
        external
        view
        override
        returns (address[] memory)
    {
        return _getStakingDestinations(account);
    }

    /**
     * @param token is the token address to stake for
     * @return currentTerm is the current latest term
     * @return latestTerm is the potential latest term
     * @return totalRemainingRewards is the as-of remaining rewards
     * @return currentReward is the total rewards at the current term
     * @return nextTermRewards is the as-of total rewards to be paid at the next term
     * @return currentStaking is the total active staking amount
     * @return nextTermStaking is the total staking amount
     */
    function getTokenInfo(address token)
        external
        view
        override
        returns (
            uint256 currentTerm,
            uint256 latestTerm,
            uint256 totalRemainingRewards,
            uint256 currentReward,
            uint256 nextTermRewards,
            uint128 currentStaking,
            uint128 nextTermStaking
        )
    {
        currentTerm = _currentTerm[token];
        latestTerm = _getLatestTerm();
        totalRemainingRewards = _totalRemainingRewards[token];
        currentReward = _termInfo[token][currentTerm].rewardSum;
        nextTermRewards = _getNextTermReward(token);
        TermInfo memory termInfo = _termInfo[token][_currentTerm[token]];
        currentStaking = termInfo.stakeSum;
        nextTermStaking = termInfo.stakeSum.add(termInfo.stakeAdd).toUint128();
    }

    /**
     * @notice Returns _termInfo[token][term].
     */
    function getTermInfo(address token, uint256 term)
        external
        view
        override
        returns (
            uint128 stakeAdd,
            uint128 stakeSum,
            uint256 rewardSum
        )
    {
        TermInfo memory termInfo = _termInfo[token][term];
        stakeAdd = termInfo.stakeAdd;
        stakeSum = termInfo.stakeSum;
        if (term == _currentTerm[token] + 1) {
            rewardSum = _getNextTermReward(token);
        } else {
            rewardSum = termInfo.rewardSum;
        }
    }

    /**
     * @return userTerm is the latest term the user has updated to
     * @return stakeAmount is the latest amount of staking from the user has updated to
     * @return nextAddedStakeAmount is the next amount of adding to stake from the user has updated to
     * @return currentReward is the latest reward getting by the user has updated to
     * @return nextLatestTermUserRewards is the as-of user rewards to be paid at the next term
     * @return depositAmount is the staking amount
     * @return withdrawableStakingAmount is the withdrawable staking amount
     */
    function getAccountInfo(address token, address account)
        external
        view
        override
        returns (
            uint256 userTerm,
            uint256 stakeAmount,
            uint128 nextAddedStakeAmount,
            uint256 currentReward,
            uint256 nextLatestTermUserRewards,
            uint128 depositAmount,
            uint128 withdrawableStakingAmount
        )
    {
        AccountInfo memory accountInfo = _accountInfo[token][account];
        userTerm = accountInfo.userTerm;
        stakeAmount = accountInfo.stakeAmount;
        nextAddedStakeAmount = accountInfo.added;
        currentReward = accountInfo.rewards;
        uint256 currentTerm = _currentTerm[token];
        TermInfo memory termInfo = _termInfo[token][currentTerm];
        uint256 nextLatestTermRewards = _getNextTermReward(token);
        nextLatestTermUserRewards = termInfo.stakeSum.add(termInfo.stakeAdd) == 0
            ? 0
            : nextLatestTermRewards.mul(accountInfo.stakeAmount.add(accountInfo.added)) /
                (termInfo.stakeSum + termInfo.stakeAdd);
        depositAmount = accountInfo.stakeAmount.add(accountInfo.added).toUint128();
        uint128 availableForVoting = _voteNum[account].toUint128();
        withdrawableStakingAmount = depositAmount < availableForVoting
            ? depositAmount
            : availableForVoting;
    }
}
