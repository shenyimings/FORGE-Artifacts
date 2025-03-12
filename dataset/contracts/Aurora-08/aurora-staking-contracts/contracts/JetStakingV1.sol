// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./ITreasury.sol";
import "./AdminControlled.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @title JetStakingV1
 * @author Aurora Team
 *
 * @dev Implementation of Jet staking contract
 *
 *      This contract implements the staking mechanics for AURORA ERC20 token.
 *      A user can stake any amount of AURORA tokens, and get rewarded in both
 *      AURORA and other stream tokens based on the rewards schedules.
 *      Stream rewards can be claimed any time however AURORA can't be claimed
 *      unless the user unstakes his full/partial amount of shares.
 *
 *      This contract is AdminControlled which has a tremendous power. However
 *      hopfully it be governed by a community wallet.
 */
contract JetStakingV1 is AdminControlled {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    bytes32 public constant AIRDROP_ROLE = keccak256("AIRDROP_ROLE");
    bytes32 public constant CLAIM_ROLE = keccak256("CLAIM_ROLE");
    uint256 constant ONE_MONTH = 2629746;
    uint256 constant FOUR_YEARS = 126227704;
    // RPS_MULTIPLIER = Aurora_max_supply x weight(1000) * 10 (large enough to always release rewards) =
    // 10**9 * 10**18 * 10**3 * 10= 10**31
    uint256 constant RPS_MULTIPLIER = 1e31;
    uint256 public totalAmountOfStakedAurora;
    uint256 public touchedAt;
    uint256 public totalAuroraShares;
    uint256 public totalStreamShares;
    address public treasury;
    address public auroraToken;
    uint256 maxWeight;
    uint256 minWeight;

    struct User {
        uint256 deposit;
        uint256 auroraShares;
        uint256 streamShares;
        mapping(uint256 => uint256) pendings; // The amount of tokens pending release for user per stream
        mapping(uint256 => uint256) releaseTime; // The release moment per stream
        mapping(uint256 => uint256) rpsDuringLastWithdrawal; // RPS or reward per share during the previous withdrawal
    }

    struct Schedule {
        uint256[] time;
        uint256[] reward;
    }

    struct Stream {
        address owner;
        address rewardToken;
        uint256 auroraDepositAmount;
        uint256 auroraClaimedAmount;
        uint256 rewardDepositAmount;
        uint256 rewardClaimedAmount;
        uint256 maxDepositAmount;
        uint256 lastTimeOwnerClaimed;
        uint256 tau;
        uint256 rps; // Reward per share for a stream j>0
        Schedule schedule;
        bool isProposed;
        bool isActive;
    }

    mapping(address => User) users;
    Stream[] streams;

    // events
    event Staked(
        address indexed user,
        uint256 amount,
        uint256 shares,
        uint256 timestamp
    );

    event Unstaked(address indexed user, uint256 amount, uint256 timestamp);

    event Pending(
        uint256 indexed streamId,
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );

    event Released(
        uint256 indexed streamId,
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );

    event StreamProposed(
        uint256 indexed streamId,
        address indexed owner,
        uint256 timestamp
    );

    event StreamProposalCancelled(
        uint256 indexed streamId,
        address indexed owner,
        uint256 timestamp
    );

    event StreamCreated(
        uint256 indexed streamId,
        address indexed owner,
        uint256 timestamp
    );

    event StreamRemoved(
        uint256 indexed streamId,
        address indexed owner,
        uint256 timestamp
    );

    modifier onlyActiveStream(uint256 streamId) {
        require(streams[streamId].isActive, "INACTIVE_STREAM");
        _;
    }

    /// @dev initialize the contract and deploys the first stream (AURORA)
    /// @notice By calling this function, the deployer of this contract must
    /// make sure that the AURORA reward amount was deposited to the treasury
    /// contract before initializing of the default AURORA stream.
    /// @param aurora token contract address
    /// @param scheduleTimes init the schedule time
    /// @param scheduleRewards init the schedule amounts
    /// @param tauAuroraStream release time constant per stream (e.g AURORA stream)
    /// @param _flags admin controlled contract flags
    /// @param _treasury the Aurora treasury contract address
    /// @param _maxWeight max stream reward weighting coefficient
    /// @param _minWeight min stream reward weighting coefficient
    function initialize(
        address aurora,
        address streamOwner,
        uint256[] memory scheduleTimes,
        uint256[] memory scheduleRewards,
        uint256 tauAuroraStream,
        uint256 _flags,
        address _treasury,
        uint256 _maxWeight,
        uint256 _minWeight
    ) public initializer {
        require(_maxWeight > _minWeight, "INVALID_WEIGHTS");
        require(
            aurora != address(0) &&
                _treasury != address(0) &&
                streamOwner != address(0),
            "INVALID_ADDRESS"
        );
        require(
            scheduleTimes.length == scheduleRewards.length,
            "INVALID_SCHEDULE_VALUES"
        );
        require(tauAuroraStream != 0, "INVALID_TAU_PERIOD");
        for (uint256 i = 1; i < scheduleTimes.length; i++) {
            require(
                scheduleTimes[i] > scheduleTimes[i - 1],
                "INVALID_SCHEDULE_TIMES"
            );
            require(
                scheduleRewards[i] <= scheduleRewards[i - 1],
                "INVALID_SCHEDULE_REWARDS"
            );
        }
        require(
            scheduleRewards[scheduleRewards.length - 1] == 0,
            "INVALID_SCHEDULE_END_REWARD"
        );
        __AdminControlled_init(_flags);
        _grantRole(AIRDROP_ROLE, msg.sender);
        _grantRole(CLAIM_ROLE, msg.sender);
        treasury = _treasury;
        auroraToken = aurora;
        maxWeight = _maxWeight;
        minWeight = _minWeight;
        //init AURORA default stream
        // This is a special stream where the reward token is the aurora token itself.
        uint256 streamId = 0;
        streams.push();
        Stream storage stream = streams[streamId];
        stream.owner = streamOwner;
        stream.rewardToken = aurora;
        stream.auroraDepositAmount = 0;
        stream.auroraClaimedAmount = 0;
        stream.maxDepositAmount = 0;
        stream.rewardDepositAmount = 0;
        stream.rewardClaimedAmount = 0;
        stream.lastTimeOwnerClaimed = block.timestamp;
        stream.schedule = Schedule(scheduleTimes, scheduleRewards);
        stream.isProposed = true;
        stream.isActive = true;
        stream.tau = tauAuroraStream;
        emit StreamProposed(streamId, streamOwner, block.timestamp);
        emit StreamCreated(streamId, streamOwner, block.timestamp);
    }

    /// @dev An admin of the staking contract can whitelist (propose) a stream.
    /// Whitelisting of the stream provides the option for the stream
    /// creator (presumably the issuing party of a specific token) to
    /// deposit some ERC-20 tokens on the staking contract and potentially
    /// get in return some AURORA tokens. Deposited ERC-20 tokens will be
    /// distributed to the stakers over some period of time.
    /// @notice treasury manager must call
    /// @param streamOwner only this account would be able to create a stream
    /// @param rewardToken the address of the ERC-20 tokens to be deposited in the stream
    /// @param auroraDepositAmount Amount of the AURORA deposited by the Admin.
    /// @param maxDepositAmount The upper amount of the tokens that should be deposited by the stream owner
    /// @param scheduleTimes array of block heights for each schedule time
    /// @param scheduleRewards array of reward amounts that are kept on the staking contract at each block height
    /// @param tau the tau is (pending release period) for this stream (e.g one day)
    function proposeStream(
        address streamOwner,
        address rewardToken,
        uint256 auroraDepositAmount,
        uint256 maxDepositAmount,
        uint256[] memory scheduleTimes,
        uint256[] memory scheduleRewards,
        uint256 tau
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _validateStreamParameters(
            streamOwner,
            rewardToken,
            maxDepositAmount,
            scheduleTimes,
            scheduleRewards,
            tau
        );
        uint256 streamId = streams.length;
        streams.push();
        Stream storage stream = streams[streamId];
        stream.owner = streamOwner;
        stream.rewardToken = rewardToken;
        stream.auroraDepositAmount = auroraDepositAmount;
        stream.auroraClaimedAmount = 0;
        stream.maxDepositAmount = maxDepositAmount;
        stream.rewardDepositAmount = 0;
        stream.rewardClaimedAmount = 0;
        stream.lastTimeOwnerClaimed = scheduleTimes[0];
        stream.schedule = Schedule(scheduleTimes, scheduleRewards);
        stream.isProposed = true;
        stream.isActive = false;
        stream.tau = tau;
        emit StreamProposed(streamId, streamOwner, block.timestamp);
        IERC20Upgradeable(auroraToken).safeTransferFrom(
            msg.sender,
            address(this),
            auroraDepositAmount
        );
    }

    /// @dev cancelStreamProposal should only called if the stream owner
    /// never created the stream after the proposal expiry date (streams[streamId].schedule.time[0]).
    /// @param streamId the stream index
    function cancelStreamProposal(uint256 streamId)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        Stream storage stream = streams[streamId];
        require(
            streams[streamId].schedule.time[0] <= block.timestamp &&
                stream.isProposed,
            "STREAM_DID_NOT_EXPIRE"
        );
        // cancel the proposal
        stream.isProposed = false;
        uint256 refundAmount = stream.auroraDepositAmount;
        stream.auroraDepositAmount = 0;
        emit StreamProposalCancelled(streamId, stream.owner, block.timestamp);
        // refund admin wallet with the stream aurora deposit
        IERC20Upgradeable(auroraToken).safeTransfer(admin, refundAmount);
    }

    /// @dev create new stream (only stream owner)
    /// stream owner must approve reward tokens to this contract.
    /// @param streamId stream id
    function createStream(uint256 streamId, uint256 rewardTokenAmount)
        external
        pausable(1)
    {
        Stream storage stream = streams[streamId];
        require(stream.isProposed, "STREAM_NOT_PROPOSED");
        require(stream.owner == msg.sender, "INVALID_STREAM_OWNER");
        require(!stream.isActive, "STREAM_ALREADY_EXISTS");
        require(
            stream.schedule.time[0] >= block.timestamp,
            "STREAM_PROPOSAL_EXPIRED"
        );
        require(
            rewardTokenAmount <= stream.maxDepositAmount,
            "INVALID_REWARD_TOKEN_AMOUNT"
        );
        stream.isActive = true;
        stream.rewardDepositAmount = rewardTokenAmount;
        emit StreamCreated(streamId, msg.sender, block.timestamp);
        if (rewardTokenAmount < stream.maxDepositAmount) {
            // refund staking admin if deposited reward tokens less than the upper limit of deposit
            uint256 refundAuroraAmount = ((stream.maxDepositAmount -
                rewardTokenAmount) * stream.auroraDepositAmount) /
                stream.maxDepositAmount;
            stream.auroraDepositAmount -= refundAuroraAmount;
            // update stream reward schedules
            _updateStreamRewardSchedules(streamId, rewardTokenAmount);
            IERC20Upgradeable(auroraToken).safeTransfer(
                admin,
                refundAuroraAmount
            );
        }
        // move Aurora tokens to treasury
        IERC20Upgradeable(auroraToken).safeTransfer(
            address(treasury),
            stream.auroraDepositAmount
        );
        // move reward tokens to treasury
        IERC20Upgradeable(stream.rewardToken).safeTransferFrom(
            msg.sender,
            address(treasury),
            rewardTokenAmount
        );
    }

    /// @dev Get the treasury balance
    /// @param token the token address
    function getTreasuryBalance(address token) public view returns (uint256) {
        return IERC20Upgradeable(token).balanceOf(treasury);
    }

    /// @dev removes a stream (only default admin role)
    /// @param streamId stream index
    /// @param streamFundReceiver receives the rest of the reward tokens in the stream
    function removeStream(uint256 streamId, address streamFundReceiver)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(streamId != 0, "AURORA_STREAM_NOT_REMOVABLE");
        Stream storage stream = streams[streamId];
        require(stream.isActive, "STREAM_ALREADY_REMOVED");
        stream.isActive = false;
        stream.isProposed = false;
        emit StreamRemoved(streamId, stream.owner, block.timestamp);
        uint256 releaseAuroraAmount = stream.auroraDepositAmount -
            stream.auroraClaimedAmount;
        uint256 releaseRewardAmount = stream.rewardDepositAmount -
            stream.rewardClaimedAmount;
        // check enough treasury balance
        uint256 auroraTreasury = getTreasuryBalance(auroraToken);
        uint256 rewardTreasury = getTreasuryBalance(stream.rewardToken);
        // move rest of the unclaimed aurora to the admin
        ITreasury(treasury).payRewards(
            admin,
            auroraToken,
            releaseAuroraAmount <= auroraTreasury
                ? releaseAuroraAmount
                : auroraTreasury // should not happen
        );
        // move the rest of rewards to the stream owner
        ITreasury(treasury).payRewards(
            streamFundReceiver,
            stream.rewardToken,
            releaseRewardAmount <= rewardTreasury
                ? releaseRewardAmount
                : rewardTreasury // should not happen
        );
    }

    /// @dev Stream owner claimable AURORA.
    /// @param streamId the stream index
    function getStreamOwnerClaimableAmount(uint256 streamId)
        public
        view
        returns (uint256)
    {
        Stream storage stream = streams[streamId];
        if (!stream.isActive) return 0;
        uint256 scheduledReward = getRewardsAmount(
            streamId,
            stream.lastTimeOwnerClaimed
        );
        return
            (scheduledReward * stream.auroraDepositAmount) /
            stream.rewardDepositAmount;
    }

    /// @dev the release of AURORA tokens to the stream creator is subjected to the same schedule as rewards.
    /// Thus if for a specific moment in time 30% of the rewards are distributed, then it means that 30% of
    /// the AURORA deposit can be withdrawn by the stream creator too.
    /// called by the stream owner
    /// @param streamId the stream index
    function releaseAuroraRewardsToStreamOwner(uint256 streamId)
        external
        pausable(1)
    {
        Stream storage stream = streams[streamId];
        require(msg.sender == stream.owner, "INVALID_STREAM_OWNER");
        require(stream.isActive, "INACTIVE_STREAM");
        uint256 auroraStreamOwnerReward = getStreamOwnerClaimableAmount(
            streamId
        );
        stream.lastTimeOwnerClaimed = block.timestamp;
        stream.auroraClaimedAmount += auroraStreamOwnerReward;
        // check enough treasury balance
        ITreasury(treasury).payRewards(
            stream.owner,
            auroraToken,
            auroraStreamOwnerReward
        );
    }

    /// @dev get the stream data
    /// @notice this function doesn't return the stream
    /// schedule due to some stake slots limitations. To
    /// get the stream schedule, refer to getStreamSchedule
    /// @param streamId the stream index
    function getStream(uint256 streamId)
        external
        view
        returns (
            address streamOwner,
            address rewardToken,
            uint256 auroraDepositAmount,
            uint256 auroraClaimedAmount,
            uint256 rewardDepositAmount,
            uint256 rewardClaimedAmount,
            uint256 maxDepositAmount,
            uint256 lastTimeOwnerClaimed,
            uint256 tau,
            bool isProposed,
            bool isActive
        )
    {
        Stream storage stream = streams[streamId];
        return (
            stream.owner,
            stream.rewardToken,
            stream.auroraDepositAmount,
            stream.auroraClaimedAmount,
            stream.rewardDepositAmount,
            stream.rewardClaimedAmount,
            stream.maxDepositAmount,
            stream.lastTimeOwnerClaimed,
            stream.tau,
            stream.isProposed,
            stream.isActive
        );
    }

    /// @dev get the stream schedule data
    /// @param streamId the stream index
    function getStreamSchedule(uint256 streamId)
        public
        view
        returns (
            uint256[] memory scheduleTimes,
            uint256[] memory scheduleRewards
        )
    {
        return (
            streams[streamId].schedule.time,
            streams[streamId].schedule.reward
        );
    }

    /// @dev get the streams count
    /// @return streams.length
    function getStreamsCount() external view returns (uint256) {
        return streams.length;
    }

    /// @notice updates treasury account
    /// @dev restricted for the admin only. Admin should pause this
    /// contract before changing the treasury address by setting the
    /// pause =1 (for changing this variable, call adminPause(1))
    /// @param _treasury treasury contract address for the reward tokens
    function updateTreasury(address _treasury)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_treasury != address(0), "INVALID_ADDRESS");
        treasury = _treasury;
    }

    /// @dev stakeOnBehalfOfOtherUsers called for airdropping Aurora users
    /// @param accounts the account address
    /// @param amounts in AURORA tokens
    /// @param batchAmount equals to the sum of amounts
    /// WARNING: rewards are not claimed during stake. Airdrop script must claim or
    /// only distribute to accounts without stake
    function stakeOnBehalfOfOtherUsers(
        address[] memory accounts,
        uint256[] memory amounts,
        uint256 batchAmount
    ) external pausable(1) onlyRole(AIRDROP_ROLE) {
        _before();
        require(accounts.length == amounts.length, "INVALID_ARRAY_LENGTH");
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
            _stake(accounts[i], amounts[i]);
        }
        require(totalAmount == batchAmount, "INVALID_BATCH_AMOUNT");
        IERC20Upgradeable(auroraToken).safeTransferFrom(
            msg.sender,
            address(treasury),
            batchAmount
        );
    }

    /// @dev stakeOnBehalfOfAnotherUser is called for airdropping Aurora users
    /// @param account the account address
    /// @param amount in AURORA tokens
    /// WARNING: rewards are not claimed during stake. Airdrop script must claim or
    /// only distribute to accounts without stake
    function stakeOnBehalfOfAnotherUser(address account, uint256 amount)
        external
        pausable(1)
        onlyRole(AIRDROP_ROLE)
    {
        _before();
        _stake(account, amount);
        IERC20Upgradeable(auroraToken).safeTransferFrom(
            msg.sender,
            address(treasury),
            amount
        );
    }

    /// @dev moves the reward for specific stream Id to pending rewards.
    /// It will require a waiting time untill it get released. Users call
    /// this in function in order to claim rewards.
    /// @param streamId stream index
    function moveRewardsToPending(uint256 streamId)
        external
        pausable(1)
        onlyActiveStream(streamId)
    {
        _before();
        _moveRewardsToPending(msg.sender, streamId);
    }

    /// @dev moves all the user rewards to pending reward.
    function moveAllRewardsToPending() external pausable(1) {
        _before();
        // Claim all streams while skipping inactive streams.
        _moveAllRewardsToPending(msg.sender);
    }

    /// @dev moves a set of stream Id rewards to pending.
    /// Allows user to select stream ids to claim from UI.
    /// @param streamIds stream indexes
    function batchMoveRewardsToPending(uint256[] memory streamIds)
        external
        pausable(1)
    {
        _before();
        _batchClaimRewards(msg.sender, streamIds);
    }

    /// @dev Claim a stream's rewards on behalf of another user.
    /// @param account the user account address.
    /// @param streamId to claim.
    function claimOnBehalfOfAnotherUser(address account, uint256 streamId)
        external
        onlyRole(CLAIM_ROLE)
    {
        _before();
        _moveRewardsToPending(account, streamId);
    }

    /// @dev Claim all stream rewards on behalf of another user.
    /// @param account the user account address.
    function claimAllOnBehalfOfAnotherUser(address account)
        external
        onlyRole(CLAIM_ROLE)
    {
        _before();
        _moveAllRewardsToPending(account);
    }

    /// @dev Claim all stream rewards on behalf of other users.
    /// @param accounts the user account addresses.
    function claimAllOnBehalfOfOtherUsers(address[] memory accounts)
        external
        onlyRole(CLAIM_ROLE)
    {
        _before();
        for (uint256 i = 0; i < accounts.length; i++) {
            _moveAllRewardsToPending(accounts[i]);
        }
    }

    /// @dev batchClaimOnBehalfOfAnotherUser when gas limits prevent users from claiming all.
    /// @param account the user account address.
    /// @param streamIds to claim.
    function batchClaimOnBehalfOfAnotherUser(
        address account,
        uint256[] memory streamIds
    ) external onlyRole(CLAIM_ROLE) {
        _before();
        _batchClaimRewards(account, streamIds);
    }

    /// @dev Claim all stream rewards on behalf of other users.
    /// @param accounts the user account addresses.
    function batchClaimOnBehalfOfOtherUsers(
        address[] memory accounts,
        uint256[] memory streamIds
    ) external onlyRole(CLAIM_ROLE) {
        _before();
        for (uint256 i = 0; i < accounts.length; i++) {
            _batchClaimRewards(accounts[i], streamIds);
        }
    }

    /// @dev a user stakes amount of AURORA tokens
    /// The user should approve these tokens to the treasury
    /// contract in order to complete the stake.
    /// @param amount is the AURORA amount.
    function stake(uint256 amount) external pausable(1) {
        _before();
        _stake(msg.sender, amount);
        IERC20Upgradeable(auroraToken).safeTransferFrom(
            msg.sender,
            address(treasury),
            amount
        );
    }

    /// @dev withdraw amount in the pending. User should wait for
    /// pending time (tau constant) in order to be able to withdraw.
    /// @param streamId stream index
    function withdraw(uint256 streamId) external pausable(1) {
        require(
            block.timestamp > users[msg.sender].releaseTime[streamId],
            "INVALID_RELEASE_TIME"
        );
        _withdraw(streamId);
    }

    /// @dev withdraw all claimed balances which have passed pending periode.
    /// This function will reach gas limit with too many streams,
    /// so the frontend will allow individual stream withdrawals and disable withdrawAll.
    function withdrawAll() external pausable(1) {
        User storage userAccount = users[msg.sender];
        for (uint256 i = 0; i < streams.length; i++) {
            if (
                userAccount.pendings[i] != 0 &&
                block.timestamp > userAccount.releaseTime[i]
            ) {
                _withdraw(i);
            }
        }
    }

    /// @dev withdraw a set of stream Ids.
    /// Allows user to select stream ids to withdraw from UI.
    /// @param streamIds to withdraw.
    function batchWithdraw(uint256[] memory streamIds) external pausable(1) {
        User storage userAccount = users[msg.sender];
        for (uint256 i = 0; i < streamIds.length; i++) {
            if (
                userAccount.pendings[streamIds[i]] != 0 &&
                block.timestamp > userAccount.releaseTime[streamIds[i]]
            ) {
                _withdraw(streamIds[i]);
            }
        }
    }

    /// @dev gets the total user deposit
    /// @param account the user address
    /// @return user total deposit in (AURORA)
    function getUserTotalDeposit(address account)
        external
        view
        returns (uint256)
    {
        return users[account].deposit;
    }

    /// @dev gets the user shares
    /// @param account the user address
    /// @return user shares
    function getUserShares(address account) external view returns (uint256) {
        return users[account].auroraShares;
    }

    /// @dev unstake amount from user shares value. The rest is re-staked
    /// @param amount to unstake
    function unstake(uint256 amount) external pausable(1) {
        _before();
        uint256 stakeValue = (totalAmountOfStakedAurora *
            users[msg.sender].auroraShares) / totalAuroraShares;
        _unstake(amount, stakeValue);
    }

    /// @dev unstake all the user's shares
    function unstakeAll() external pausable(1) {
        _before();
        uint256 stakeValue = (totalAmountOfStakedAurora *
            users[msg.sender].auroraShares) / totalAuroraShares;
        _unstake(stakeValue, stakeValue);
    }

    /// @dev gets a user stream shares
    /// @param streamId stream index
    /// @param account the user address
    /// @return user stream shares
    function getAmountOfShares(uint256 streamId, address account)
        external
        view
        returns (uint256)
    {
        if (streamId == 0) return users[account].auroraShares;
        return users[account].streamShares;
    }

    /// @dev gets reward per share (RPS) for a stream
    /// @param streamId stream index
    /// @return streams[streamId].rps
    function getRewardPerShare(uint256 streamId)
        external
        view
        returns (uint256)
    {
        return streams[streamId].rps;
    }

    /// @dev calculates and gets the latest released rewards.
    /// @param streamId stream index
    /// @return rewards released since last update.
    function getRewardsAmount(uint256 streamId, uint256 lastUpdate)
        public
        view
        returns (uint256)
    {
        uint256 streamStart = streams[streamId].schedule.time[0];
        if (block.timestamp <= streamStart) return 0; // Stream didn't start
        uint256 streamEnd = streams[streamId].schedule.time[
            streams[streamId].schedule.time.length - 1
        ];
        if (lastUpdate >= streamEnd) return 0; // Stream schedule ended, all rewards released
        uint256 start;
        uint256 end;
        if (lastUpdate > streamStart) {
            start = lastUpdate;
        } else {
            // Release rewards from stream start.
            start = streamStart;
        }
        if (block.timestamp < streamEnd) {
            end = block.timestamp;
        } else {
            // The stream already finished between the last update and now.
            end = streamEnd;
        }
        return rewardsSchedule(streamId, start, end);
    }

    /// @dev calculates and gets the latest reward per share (RPS) for a stream
    /// @param streamId stream index
    /// @return streams[streamId].rps + scheduled reward up till now
    function getLatestRewardPerShare(uint256 streamId)
        public
        view
        returns (uint256)
    {
        require(streamId != 0, "AURORA_REWARDS_COMPOUND");
        require(totalStreamShares != 0, "ZERO_STREAM_SHARES");
        return
            streams[streamId].rps +
            (getRewardsAmount(streamId, touchedAt) * RPS_MULTIPLIER) /
            totalStreamShares;
    }

    /// @dev gets the user's reward per share (RPS) for a stream
    /// @param streamId stream index
    /// @return user.rpsDuringLastWithdrawal[streamId]
    function getRewardPerShareForUser(uint256 streamId, address account)
        external
        view
        returns (uint256)
    {
        return users[account].rpsDuringLastWithdrawal[streamId];
    }

    /// @dev gets the user's stream claimable amount
    /// @param streamId stream index
    /// @return (latesRPS - user.rpsDuringLastWithdrawal) * user.shares
    function getStreamClaimableAmount(uint256 streamId, address account)
        external
        view
        returns (uint256)
    {
        uint256 latestRps = getLatestRewardPerShare(streamId);
        User storage userAccount = users[account];
        uint256 userRps = userAccount.rpsDuringLastWithdrawal[streamId];
        uint256 userShares = userAccount.streamShares;
        return ((latestRps - userRps) * userShares) / RPS_MULTIPLIER;
    }

    /// @dev gets the user's stream pending reward
    /// @param streamId stream index
    /// @param account user account
    /// @return user.pendings[streamId]
    function getPending(uint256 streamId, address account)
        external
        view
        returns (uint256)
    {
        return users[account].pendings[streamId];
    }

    /// @dev gets the user's stream reward release time
    /// @param streamId stream index
    /// @param account user account
    /// @return user.releaseTime[streamId]
    function getReleaseTime(uint256 streamId, address account)
        external
        view
        returns (uint256)
    {
        return users[account].releaseTime[streamId];
    }

    /// @dev gets the total amount of staked aurora
    /// @return totalAmountOfStakedAurora + latest reward schedule
    function getTotalAmountOfStakedAurora() external view returns (uint256) {
        if (touchedAt == 0) return 0;
        return totalAmountOfStakedAurora + getRewardsAmount(0, touchedAt);
    }

    /// @dev gets start index and end index in a stream schedule
    /// @param streamId stream index
    /// @param start start time (in seconds)
    /// @param end end time (in seconds)
    function startEndScheduleIndex(
        uint256 streamId,
        uint256 start,
        uint256 end
    ) public view returns (uint256 startIndex, uint256 endIndex) {
        Schedule storage schedule = streams[streamId].schedule;
        require(schedule.time.length > 0, "NO_SCHEDULE");
        require(
            end > start &&
                start >= schedule.time[0] &&
                end <= schedule.time[schedule.time.length - 1],
            "INVALID_SCHEDULE_PARAMETERS"
        );
        // find start index and end index
        for (uint256 i = 0; i < schedule.time.length - 1; i++) {
            if (start < schedule.time[i]) {
                startIndex = i - 1;
                break;
            }
        }

        for (uint256 i = schedule.time.length - 1; i > 0; i--) {
            if (end >= schedule.time[i]) {
                endIndex = i;
                break;
            }
        }
    }

    /// @dev calculate the total amount of the released tokens within a period (start & end)
    /// @param streamId the stream index
    /// @param start is the start timestamp within the schedule
    /// @param end is the end timestamp (e.g block.timestamp .. now)
    /// @return amount of the released tokens for that period
    function rewardsSchedule(
        uint256 streamId,
        uint256 start,
        uint256 end
    ) public view returns (uint256) {
        require(end > start, "INVALID_REWARD_QUERY_PERIODE");
        Schedule storage schedule = streams[streamId].schedule;
        require(start >= schedule.time[0], "QUERY_BEFORE_SCHEDULE_START");
        require(
            end <= schedule.time[schedule.time.length - 1],
            "QUERY_AFTER_SCHEDULE_END"
        );
        uint256 startIndex;
        uint256 endIndex;
        (startIndex, endIndex) = startEndScheduleIndex(streamId, start, end);
        uint256 rewardScheduledAmount = 0;
        uint256 reward = 0;
        if (startIndex == endIndex) {
            // start and end are within the same schedule period
            reward =
                schedule.reward[startIndex] -
                schedule.reward[startIndex + 1];
            rewardScheduledAmount =
                (reward * (end - start)) /
                (schedule.time[startIndex + 1] - schedule.time[startIndex]);
        } else {
            // start and end are not within the same schedule period
            // Reward during the startIndex period
            reward = (schedule.reward[startIndex] -
                schedule.reward[startIndex + 1]);
            rewardScheduledAmount =
                (reward * (schedule.time[startIndex + 1] - start)) /
                (schedule.time[startIndex + 1] - schedule.time[startIndex]);
            // Reward during the period from startIndex + 1  to endIndex - 1
            for (uint256 i = startIndex + 1; i < endIndex; i++) {
                reward = schedule.reward[i] - schedule.reward[i + 1];
                rewardScheduledAmount += reward;
            }
            // Reward during the endIndex period
            if (end > schedule.time[endIndex]) {
                reward =
                    schedule.reward[endIndex] -
                    schedule.reward[endIndex + 1];
                rewardScheduledAmount +=
                    (reward * (end - schedule.time[endIndex])) /
                    (schedule.time[startIndex + 1] - schedule.time[startIndex]);
            }
        }
        return rewardScheduledAmount;
    }

    /// @dev called before touching the contract reserves (stake/unstake)
    function _before() internal {
        if (touchedAt == block.timestamp) return; // Already updated by previous tx in same block.
        if (totalAuroraShares != 0) {
            // Don't release rewards if there are no stakers.
            totalAmountOfStakedAurora += getRewardsAmount(0, touchedAt);
            for (uint256 i = 1; i < streams.length; i++) {
                if (streams[i].isActive) {
                    // If stream becomes blacklisted, no more rewards are released.
                    streams[i].rps = getLatestRewardPerShare(i);
                }
            }
        }
        touchedAt = block.timestamp;
    }

    /// @dev calculate the weighted stream shares at given timeshamp.
    /// @param timestamp the timestamp refering to the current or older timestamp
    function _weightedShares(uint256 shares, uint256 timestamp)
        internal
        view
        returns (uint256)
    {
        uint256 slopeStart = streams[0].schedule.time[0] + ONE_MONTH;
        uint256 slopeEnd = slopeStart + FOUR_YEARS;
        if (timestamp <= slopeStart) return shares * maxWeight;
        if (timestamp >= slopeEnd) return shares * minWeight;
        return
            shares *
            minWeight +
            (shares * (maxWeight - minWeight) * (slopeEnd - timestamp)) /
            (slopeEnd - slopeStart);
    }

    /// @dev allocate the collected reward to the pending tokens
    /// Rewards will become withdrawable after the release time.
    /// @param account is the staker address
    /// @param streamId the stream index
    function _moveRewardsToPending(address account, uint256 streamId) internal {
        require(streamId != 0, "AURORA_REWARDS_COMPOUND");
        User storage userAccount = users[account];
        uint256 reward = ((streams[streamId].rps -
            userAccount.rpsDuringLastWithdrawal[streamId]) *
            userAccount.streamShares) / RPS_MULTIPLIER;
        if (reward == 0) return; // All rewards claimed or stream schedule didn't start
        userAccount.pendings[streamId] += reward;
        userAccount.rpsDuringLastWithdrawal[streamId] = streams[streamId].rps;
        userAccount.releaseTime[streamId] =
            block.timestamp +
            streams[streamId].tau;
        // If the stream is blacklisted, remaining unclaimed rewards will be transfered out.
        streams[streamId].rewardClaimedAmount += reward;
        emit Pending(
            streamId,
            account,
            userAccount.pendings[streamId],
            block.timestamp
        );
    }

    /// @dev move all the streams rewards for a user to the pending tokens
    /// @param account is the staker address
    function _moveAllRewardsToPending(address account) internal {
        for (uint256 i = 1; i < streams.length; i++) {
            if (streams[i].isActive) _moveRewardsToPending(account, i);
        }
    }

    /// @dev moves a set of stream Id rewards to pending.
    /// `_before` must be called before to update the streams rps.
    /// @param account the user account address.
    /// @param streamIds to claim.
    function _batchClaimRewards(address account, uint256[] memory streamIds)
        internal
    {
        for (uint256 i = 0; i < streamIds.length; i++) {
            if (streams[streamIds[i]].isActive)
                _moveRewardsToPending(account, streamIds[i]);
        }
    }

    /// @dev calculate the shares for a user per AURORA stream and other streams
    /// @param amount the staked amount
    /// WARNING: rewards are not claimed during stake.
    /// The UI must make sure to claim rewards before adding more stake.
    /// Unclaimed rewards will be lost.
    /// `_before()` must be called before `_stake` to update streams rps
    /// compounded AURORA rewards.
    function _stake(address account, uint256 amount) internal {
        // recalculation of shares for user
        User storage userAccount = users[account];
        uint256 _amountOfShares = 0;
        if (totalAuroraShares == 0) {
            // initialize the number of shares (_amountOfShares) owning 100% of the stake (amount)
            _amountOfShares = amount;
        } else {
            // Round up (+1) so users don't get less sharesValue than their staked amount
            _amountOfShares =
                (amount * totalAuroraShares) /
                totalAmountOfStakedAurora +
                1;
        }
        userAccount.auroraShares += _amountOfShares;
        totalAuroraShares += _amountOfShares;
        totalAmountOfStakedAurora += amount;
        userAccount.deposit += amount;

        // Calculate stream shares
        uint256 weightedAmountOfSharesPerStream = _weightedShares(
            _amountOfShares,
            block.timestamp
        );
        totalStreamShares += weightedAmountOfSharesPerStream;
        userAccount.streamShares += weightedAmountOfSharesPerStream;
        for (uint256 i = 1; i < streams.length; i++) {
            userAccount.rpsDuringLastWithdrawal[i] = streams[i].rps; // The new shares should not claim old rewards
        }
        emit Staked(account, amount, _amountOfShares, block.timestamp);
    }

    /// WARNING: rewards are not claimed during unstake.
    /// The UI must make sure to claim rewards before unstaking.
    /// Unclaimed rewards will be lost.
    function _unstake(uint256 amount, uint256 stakeValue) internal {
        require(amount != 0, "ZERO_AMOUNT");
        require(amount <= stakeValue, "NOT_ENOUGH_STAKE_BALANCE");
        User storage userAccount = users[msg.sender];
        // move rewards to pending
        // remove the shares from everywhere
        totalAuroraShares -= userAccount.auroraShares;
        totalStreamShares -= userAccount.streamShares;
        userAccount.auroraShares = 0;
        userAccount.streamShares = 0;
        // update the total Aurora staked and deposits
        totalAmountOfStakedAurora -= stakeValue;
        userAccount.deposit = 0;
        // move unstaked AURORA to pending.
        userAccount.pendings[0] += amount;
        userAccount.releaseTime[0] = block.timestamp + streams[0].tau;
        emit Pending(0, msg.sender, userAccount.pendings[0], block.timestamp);
        emit Unstaked(msg.sender, amount, block.timestamp);
        // restake the rest
        uint256 amountToRestake = stakeValue - amount;
        if (amountToRestake > 0) {
            _stake(msg.sender, amountToRestake);
        }
    }

    /// @dev validates the stream parameters prior proposing it.
    /// @param streamOwner stream owner address
    /// @param rewardToken stream reward token address
    /// @param maxDepositAmount the max reward token deposit
    /// @param scheduleTimes the stream schedule time list
    /// @param scheduleRewards the stream schedule reward list
    /// @param tau the tau is (pending release period) for this stream (e.g one day)
    function _validateStreamParameters(
        address streamOwner,
        address rewardToken,
        uint256 maxDepositAmount,
        uint256[] memory scheduleTimes,
        uint256[] memory scheduleRewards,
        uint256 tau
    ) internal view {
        require(streamOwner != address(0), "INVALID_STREAM_OWNER_ADDRESS");
        require(rewardToken != address(0), "INVALID_REWARD_TOKEN_ADDRESS");
        require(maxDepositAmount > 0, "INVALID_MAX_DEPOSITED_AMOUNT_VALUE");
        // scheduleTimes[0] == proposal expiration time
        require(
            scheduleTimes[0] > block.timestamp,
            "INVALID_STREAM_EXPIRATION_DATE"
        );
        require(
            scheduleTimes.length == scheduleRewards.length,
            "INVALID_SCHEDULE_VALUES"
        );
        require(tau != 0, "INVALID_TAU_PERIOD");
        for (uint256 i = 1; i < scheduleTimes.length; i++) {
            require(
                scheduleTimes[i] > scheduleTimes[i - 1],
                "INVALID_SCHEDULE_TIMES"
            );
            require(
                scheduleRewards[i] <= scheduleRewards[i - 1],
                "INVALID_SCHEDULE_REWARDS"
            );
        }
        require(
            scheduleRewards[scheduleRewards.length - 1] == 0,
            "INVALID_SCHEDULE_END_REWARD"
        );
    }

    /// @dev updates the stream reward schedule if the reward token amount is less than
    /// the max deposit amount.
    /// @param streamId the stream index
    /// @param rewardTokenAmount the stream reward token amount
    function _updateStreamRewardSchedules(
        uint256 streamId,
        uint256 rewardTokenAmount
    ) internal {
        uint256 suggestedAmount = streams[streamId].schedule.reward[0];
        for (uint256 i = 0; i < streams[streamId].schedule.reward.length; i++) {
            streams[streamId].schedule.reward[i] =
                (streams[streamId].schedule.reward[i] * rewardTokenAmount) /
                suggestedAmount;
        }
    }

    /// @dev withdraw stream rewards after the release time.
    /// @param streamId the stream index
    function _withdraw(uint256 streamId) internal {
        User storage userAccount = users[msg.sender];
        uint256 pendingAmount = userAccount.pendings[streamId];
        userAccount.pendings[streamId] = 0;
        emit Released(streamId, msg.sender, pendingAmount, block.timestamp);
        ITreasury(treasury).payRewards(
            msg.sender,
            streams[streamId].rewardToken,
            pendingAmount
        );
    }
}
