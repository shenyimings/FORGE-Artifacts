//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

/**
 * @title ApeCoin Staking Contract
 * @notice Stake ApeCoin across four different pools that release hourly rewards
 * @author HorizenLabs
 */
interface IApeCoinStaking {

    /// @notice State for ApeCoin, BAYC, MAYC, and Pair Pools
    struct Pool {
        uint256 lastRewardedTimestampHour;
        uint256 lastRewardsRangeIndex;
        uint256 stakedAmount;
        uint256 accumulatedRewardsPerShare;
        TimeRange[] timeRanges;
    }

    /// @notice Pool rules valid for a given duration of time.
    /// @dev All TimeRange timestamp values must represent whole hours
    struct TimeRange {
        uint256 startTimestampHour;
        uint256 endTimestampHour;
        uint256 rewardsPerHour;
        uint256 capPerPosition;
    }

    /// @dev Convenience struct for front-end applications
    struct PoolUI {
        uint256 poolId;
        uint256 stakedAmount;
        TimeRange currentTimeRange;
    }

    /// @dev Per address amount and reward tracking
    struct Position {
        uint256 stakedAmount;
        int256 rewardsDebt;
    }

    /// @dev Struct for depositing and withdrawing from the BAYC and MAYC NFT pools
    struct SingleNft {
        uint256 tokenId;
        uint256 amount;
    }
    /// @dev Struct for depositing and withdrawing from the BAKC (Pair) pool
    struct PairNftWithAmount {
        uint256 mainTokenId;
        uint256 bakcTokenId;
        uint256 amount;
    }
    /// @dev Struct for claiming from an NFT pool
    struct PairNft {
        uint256 mainTokenId;
        uint256 bakcTokenId;
    }
    /// @dev NFT paired status.  Can be used bi-directionally (BAYC/MAYC -> BAKC) or (BAKC -> BAYC/MAYC)
    struct PairingStatus {
        uint256 tokenId;
        bool isPaired;
    }

    // @dev UI focused payload
    struct DashboardStake {
        uint256 poolId;
        uint256 tokenId;
        uint256 deposited;
        uint256 unclaimed;
        uint256 rewards24hr;
        DashboardPair pair;
    }
    /// @dev Sub struct for DashboardStake
    struct DashboardPair {
        uint256 mainTokenId;
        uint256 mainTypePoolId;
    }

    // Deposit/Commit Methods

    /**
     * @notice Deposit ApeCoin to the ApeCoin Pool
     * @param _amount Amount in ApeCoin
     * @param _recipient Address the deposit it stored to
     * @dev ApeCoin deposit must be >= 1 ApeCoin
     */
    function depositApeCoin(uint256 _amount, address _recipient) external;

    /**
     * @notice Deposit ApeCoin to the ApeCoin Pool
     * @param _amount Amount in ApeCoin
     * @dev Deposit on behalf of msg.sender. ApeCoin deposit must be >= 1 ApeCoin
     */
    function depositSelfApeCoin(uint256 _amount) external;

    /**
     * @notice Deposit ApeCoin to the BAYC Pool
     * @param _nfts Array of SingleNft structs
     * @dev Commits 1 or more BAYC NFTs, each with an ApeCoin amount to the BAYC pool.\
     * Each BAYC committed must attach an ApeCoin amount >= 1 ApeCoin and <= the BAYC pool cap amount.
     */
    function depositBAYC(SingleNft[] calldata _nfts) external;

    /**
     * @notice Deposit ApeCoin to the MAYC Pool
     * @param _nfts Array of SingleNft structs
     * @dev Commits 1 or more MAYC NFTs, each with an ApeCoin amount to the MAYC pool.\
     * Each MAYC committed must attach an ApeCoin amount >= 1 ApeCoin and <= the MAYC pool cap amount.
     */
    function depositMAYC(SingleNft[] calldata _nfts) external;

    /**
     * @notice Deposit ApeCoin to the Pair Pool, where Pair = (BAYC + BAKC) or (MAYC + BAKC)
     * @param _baycPairs Array of PairNftWithAmount structs
     * @param _maycPairs Array of PairNftWithAmount structs
     * @dev Commits 1 or more Pairs, each with an ApeCoin amount to the Pair pool.\
     * Each BAKC committed must attach an ApeCoin amount >= 1 ApeCoin and <= the Pair pool cap amount.\
     * Example 1: BAYC + BAKC + 1 ApeCoin:  [[0, 0, "1000000000000000000"],[]]\
     * Example 2: MAYC + BAKC + 1 ApeCoin:  [[], [0, 0, "1000000000000000000"]]\
     * Example 3: (BAYC + BAKC + 1 ApeCoin) and (MAYC + BAKC + 1 ApeCoin): [[0, 0, "1000000000000000000"], [0, 1, "1000000000000000000"]]
     */
    function depositBAKC(PairNftWithAmount[] calldata _baycPairs, PairNftWithAmount[] calldata _maycPairs) external;
    // Claim Rewards Methods

    /**
     * @notice Claim rewards for msg.sender and send to recipient
     * @param _recipient Address to send claim reward to
     */
    function claimApeCoin(address _recipient) external;

    /// @notice Claim and send rewards
    function claimSelfApeCoin() external;

    /**
     * @notice Claim rewards for array of BAYC NFTs and send to recipient
     * @param _nfts Array of NFTs owned and committed by the msg.sender
     * @param _recipient Address to send claim reward to
     */
    function claimBAYC(uint256[] calldata _nfts, address _recipient) external;

    /**
     * @notice Claim rewards for array of BAYC NFTs
     * @param _nfts Array of NFTs owned and committed by the msg.sender
     */
    function claimSelfBAYC(uint256[] calldata _nfts) external;

    /**
     * @notice Claim rewards for array of MAYC NFTs and send to recipient
     * @param _nfts Array of NFTs owned and committed by the msg.sender
     * @param _recipient Address to send claim reward to
     */
    function claimMAYC(uint256[] calldata _nfts, address _recipient) external;

    /**
     * @notice Claim rewards for array of MAYC NFTs
     * @param _nfts Array of NFTs owned and committed by the msg.sender
     */
    function claimSelfMAYC(uint256[] calldata _nfts) external;

    /**
     * @notice Claim rewards for array of Paired NFTs and send to recipient
     * @param _baycPairs Array of Paired BAYC NFTs owned and committed by the msg.sender
     * @param _maycPairs Array of Paired MAYC NFTs owned and committed by the msg.sender
     * @param _recipient Address to send claim reward to
     */
    function claimBAKC(PairNft[] calldata _baycPairs, PairNft[] calldata _maycPairs, address _recipient) external;

    /**
     * @notice Claim rewards for array of Paired NFTs
     * @param _baycPairs Array of Paired BAYC NFTs owned and committed by the msg.sender
     * @param _maycPairs Array of Paired MAYC NFTs owned and committed by the msg.sender
     */
    function claimSelfBAKC(PairNft[] calldata _baycPairs, PairNft[] calldata _maycPairs) external;

    // Uncommit/Withdraw Methods

    /**
     * @notice Withdraw staked ApeCoin from the ApeCoin pool.  Performs an automatic claim as part of the withdraw process.
     * @param _amount Amount of ApeCoin
     * @param _recipient Address to send withdraw amount and claim to
     */
    function withdrawApeCoin(uint256 _amount, address _recipient) external;

    /**
     * @notice Withdraw staked ApeCoin from the ApeCoin pool.  If withdraw is total staked amount, performs an automatic claim.
     * @param _amount Amount of ApeCoin
     */
    function withdrawSelfApeCoin(uint256 _amount) external;

    /**
     * @notice Withdraw staked ApeCoin from the BAYC pool.  If withdraw is total staked amount, performs an automatic claim.
     * @param _nfts Array of BAYC NFT's with staked amounts
     * @param _recipient Address to send withdraw amount and claim to
     */
    function withdrawBAYC(SingleNft[] calldata _nfts, address _recipient) external;

    /**
     * @notice Withdraw staked ApeCoin from the BAYC pool.  If withdraw is total staked amount, performs an automatic claim.
     * @param _nfts Array of BAYC NFT's with staked amounts
     */
    function withdrawSelfBAYC(SingleNft[] calldata _nfts) external;

    /**
     * @notice Withdraw staked ApeCoin from the MAYC pool.  If withdraw is total staked amount, performs an automatic claim.
     * @param _nfts Array of MAYC NFT's with staked amounts
     * @param _recipient Address to send withdraw amount and claim to
     */
    function withdrawMAYC(SingleNft[] calldata _nfts, address _recipient) external;

    /**
     * @notice Withdraw staked ApeCoin from the MAYC pool.  If withdraw is total staked amount, performs an automatic claim.
     * @param _nfts Array of MAYC NFT's with staked amounts
     */
    function withdrawSelfMAYC(SingleNft[] calldata _nfts) external;

    /**
     * @notice Withdraw staked ApeCoin from the Pair pool.  If withdraw is total staked amount, performs an automatic claim.
     * @param _baycPairs Array of Paired BAYC NFT's with staked amounts
     * @param _maycPairs Array of Paired MAYC NFT's with staked amounts
     * @dev if pairs have split ownership and BAKC is attempting a withdraw, the withdraw must be for the total staked amount
     */
    function withdrawBAKC(PairNftWithAmount[] calldata _baycPairs, PairNftWithAmount[] calldata _maycPairs) external;

    // Pool Methods

    /**
     * @return The amount of ApeCoin rewards to be distributed by pool for a given time range
     * @param _poolId Available pool values 0-3
     * @param _from Whole hour timestamp representation
     * @param _to Whole hour timestamp representation
     */
    function rewardsBy(uint256 _poolId, uint256 _from, uint256 _to) external view returns (uint256, uint256);

    /**
     * @dev Updates reward variables `lastRewardedTimestampHour`, `accumulatedRewardsPerShare` and `lastRewardsRangeIndex`
     * for a given pool.
     * @param _poolId Available pool values 0-3
     */
    function updatePool(uint256 _poolId) external;

    function getPoolsUI() external view returns (PoolUI memory, PoolUI memory, PoolUI memory, PoolUI memory);

    /**
     * @return staked amount for addressPosition [APECOIN] and nftPositions [BAYC, MAYC, and Pair(BAKC)] for voting.
     */
    function stakedTotal(address _addr) external view returns (uint256);

    /**
     * @return staked amount, pending rewards, and estimated rewards over the last 24 hours
     *      for addressPosition [APECOIN, BAYC, MAYC, BAKC].
     */
    function getAllStakes(address _address) external view returns (DashboardStake[] memory);

    /**
     * @return staked amount, pending rewards, and estimated rewards over the last 24 hours
     *      for addressPosition [APECOIN].
     */
    function getApeCoinStake(address _address) external view returns (DashboardStake memory);

    /**
     * @return staked amount, pending rewards, and estimated rewards over the last 24 hours
     *      for addressPosition [BAYC].
     */
    function getBaycStakes(address _address) external view returns (DashboardStake[] memory);

    /**
     * @return staked amount, pending rewards, and estimated rewards over the last 24 hours
     *      for addressPosition [MAYC].
     */
    function getMaycStakes(address _address) external view returns (DashboardStake[] memory);

    /**
     * @return staked amount, pending rewards, and estimated rewards over the last 24 hours
     *      for addressPosition [BAKC].
     */
    function getBakcStakes(address _address) external view returns (DashboardStake[] memory);

    /**
     * @return staked amount, pending rewards, and estimated rewards over the last 24 hours
     *      for addressPosition when BAKC Pool Pair is split.
     *      ie (BAYC/MAYC) and BAKC in pair pool have different owners.
     */
    function getSplitStakes(address _address) external view returns (DashboardStake[] memory);

    /**
     * @return current amount of claimable $APE rewards for a given position from a given pool.
     * @param _poolId Available pool values 0-3
     * @param _address Address to lookup Position for
     * @param _tokenId An NFT id
     */
    function pendingRewards(uint256 _poolId, address _address, uint256 _tokenId) external view returns (uint256);
}