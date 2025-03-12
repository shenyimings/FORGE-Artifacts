// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../../../interfaces/gov/IGovPool.sol";

/**
 * This contract is responsible for securely storing user's funds that are used during the voting. These are either
 * ERC20 tokens or NFTs
 */
interface IGovUserKeeper {
    /// @notice The struct holds information about user deposited tokens
    /// @param tokens the amount of deposited tokens
    /// @param nfts the array of deposited nfts
    struct BalanceInfo {
        uint256 tokens;
        EnumerableSet.UintSet nfts;
    }

    /// @notice The struct holds information about user balances
    /// @param balances matching vote types with balance infos
    /// @param nftsPowers matching vote types with cached nfts powers
    /// @param delegatedBalances matching delegatees with balances infos
    /// @param delegatedNftPowers matching delegatees with delegated nft powers
    /// @param allDelegatedBalance the balance info of all delegated assets
    /// @param delegatees the array of delegatees
    /// @param maxTokensLocked the upper bound of currently locked tokens
    /// @param lockedInProposals the amount of deposited tokens locked in proposals
    struct UserInfo {
        mapping(IGovPool.VoteType => BalanceInfo) balances;
        mapping(IGovPool.VoteType => uint256) nftsPowers;
        mapping(address => BalanceInfo) delegatedBalances;
        mapping(address => uint256) delegatedNftPowers;
        BalanceInfo allDelegatedBalance;
        EnumerableSet.AddressSet delegatees;
        uint256 maxTokensLocked;
        mapping(uint256 => uint256) lockedInProposals;
    }

    /// @notice The struct holds information about nft contract
    /// @param nftAddress the address of the nft
    /// @param isSupportPower boolean flag, if true then nft contract supports power
    /// @param individualPower the voting power an nft
    /// @param totalSupply the total supply of nfts that are not enumerable
    /// @param nftMinPower matching nft ids to their minimal powers
    struct NFTInfo {
        address nftAddress;
        bool isSupportPower;
        uint256 individualPower;
        uint256 totalSupply;
        mapping(uint256 => uint256) nftMinPower;
    }

    /// @notice The struct that is used in view functions of contract as a return argument
    /// @param power the total vote power of a user
    /// @param rawPower the total deposited assets power of a user
    /// @param nftPower the total nft power of a user
    /// @param rawNftPower the total deposited nft power of a user
    /// @param perNftPower the power of every nft, bounded by index with nftIds
    /// @param ownedBalance the owned erc20 balance, decimals = 18
    /// @param ownedLength the amount of owned nfts
    /// @param nftIds the array of nft ids, bounded by index with perNftPower
    struct VotingPowerView {
        uint256 power;
        uint256 rawPower;
        uint256 nftPower;
        uint256 rawNftPower;
        uint256[] perNftPower;
        uint256 ownedBalance;
        uint256 ownedLength;
        uint256[] nftIds;
    }

    /// @notice The struct that is used in view functions of contract as a return argument
    /// @param delegatee the address of delegatee (person who gets delegation)
    /// @param delegatedTokens the amount of delegated tokens
    /// @param delegatedNfts the array of delegated nfts, bounded by index with perNftPower
    /// @param nftPower the total power of delegated nfts
    /// @param perNftPower the array of nft power, bounded by index with delegatedNfts
    struct DelegationInfoView {
        address delegatee;
        uint256 delegatedTokens;
        uint256[] delegatedNfts;
        uint256 nftPower;
        uint256[] perNftPower;
    }

    /// @notice The function for injecting dependencies from the GovPool
    /// @param contractsRegistry the address of Contracts Registry
    function setDependencies(address contractsRegistry, bytes memory) external;

    /// @notice The function for depositing tokens
    /// @param payer the address of depositor
    /// @param receiver the deposit receiver address
    /// @param amount the erc20 deposit amount
    function depositTokens(address payer, address receiver, uint256 amount) external payable;

    /// @notice The function for withdrawing tokens
    /// @param payer the address from whom to withdraw the tokens
    /// @param receiver the withdrawal receiver address
    /// @param amount the erc20 withdrawal amount
    function withdrawTokens(address payer, address receiver, uint256 amount) external;

    /// @notice The function for delegating tokens
    /// @param delegator the address of delegator
    /// @param delegatee the address of delegatee
    /// @param amount the erc20 delegation amount
    function delegateTokens(address delegator, address delegatee, uint256 amount) external;

    /// @notice The function for delegating tokens from Treasury
    /// @param delegatee the address of delegatee
    /// @param amount the erc20 delegation amount
    function delegateTokensTreasury(address delegatee, uint256 amount) external payable;

    /// @notice The function for undelegating tokens
    /// @param delegator the address of delegator
    /// @param delegatee the address of delegatee
    /// @param amount the erc20 undelegation amount
    function undelegateTokens(address delegator, address delegatee, uint256 amount) external;

    /// @notice The function for undelegating tokens from Treasury
    /// @param delegatee the address of delegatee
    /// @param amount the erc20 undelegation amount
    function undelegateTokensTreasury(address delegatee, uint256 amount) external;

    /// @notice The function for depositing nfts
    /// @param payer the address of depositor
    /// @param receiver the deposit receiver address
    /// @param nftIds the array of deposited nft ids
    function depositNfts(address payer, address receiver, uint256[] calldata nftIds) external;

    /// @notice The function for withdrawing nfts
    /// @param payer the address from whom to withdraw the nfts
    /// @param receiver the withdrawal receiver address
    /// @param nftIds the withdrawal nft ids
    function withdrawNfts(address payer, address receiver, uint256[] calldata nftIds) external;

    /// @notice The function for delegating nfts
    /// @param delegator the address of delegator
    /// @param delegatee the address of delegatee
    /// @param nftIds the array of delegated nft ids
    function delegateNfts(
        address delegator,
        address delegatee,
        uint256[] calldata nftIds
    ) external;

    /// @notice The function for delegating nfts from Treasury
    /// @param delegatee the address of delegatee
    /// @param nftIds the array of delegated nft ids
    function delegateNftsTreasury(address delegatee, uint256[] calldata nftIds) external;

    /// @notice The function for undelegating nfts
    /// @param delegator the address of delegator
    /// @param delegatee the address of delegatee
    /// @param nftIds the array of undelegated nft ids
    function undelegateNfts(
        address delegator,
        address delegatee,
        uint256[] calldata nftIds
    ) external;

    /// @notice The function for undelegating nfts from Treasury
    /// @param delegatee the address of delegatee
    /// @param nftIds the array of undelegated nft ids
    function undelegateNftsTreasury(address delegatee, uint256[] calldata nftIds) external;

    /// @notice The function for recalculating max token locked amount of a user
    /// @param lockedProposals the array of proposal ids for recalculation
    /// @param voter the address of voter
    function updateMaxTokenLockedAmount(
        uint256[] calldata lockedProposals,
        address voter
    ) external;

    /// @notice The function for locking tokens in a proposal
    /// @param proposalId the id of proposal
    /// @param voter the address of voter
    /// @param amount the amount of tokens to lock
    function lockTokens(uint256 proposalId, address voter, uint256 amount) external;

    /// @notice The function for unlocking tokens in proposal
    /// @param proposalId the id of proposal
    /// @param voter the address of voter
    function unlockTokens(uint256 proposalId, address voter) external;

    /// @notice The function for locking nfts
    /// @param voter the address of voter
    /// @param voteType the type of vote
    /// @param nftIds the array of nft ids to lock
    function lockNfts(
        address voter,
        IGovPool.VoteType voteType,
        uint256[] calldata nftIds
    ) external;

    /// @notice The function for unlocking nfts
    /// @param nftIds the array of nft ids to unlock
    function unlockNfts(uint256[] calldata nftIds) external;

    /// @notice The function for recalculating power of nfts
    /// @param nftIds the array of nft ids to recalculate the power for
    function updateNftPowers(uint256[] calldata nftIds) external;

    /// @notice The function for setting erc20 address
    /// @param _tokenAddress the erc20 address
    function setERC20Address(address _tokenAddress) external;

    /// @notice The function for setting erc721 address
    /// @param _nftAddress the erc721 address
    /// @param individualPower the voting power of an nft
    /// @param nftsTotalSupply the total supply of nft contract
    function setERC721Address(
        address _nftAddress,
        uint256 individualPower,
        uint256 nftsTotalSupply
    ) external;

    /// @notice The function for getting erc20 address
    /// @return `tokenAddress` the erc20 address
    function tokenAddress() external view returns (address);

    /// @notice The function for getting erc721 address
    /// @return `nftAddress` the erc721 address
    function nftAddress() external view returns (address);

    /// @notice The function for getting nft info
    /// @return isSupportPower boolean flag, if true then nft contract supports power
    /// @return individualPower the voting power an nft
    /// @return totalSupply the total supply of nfts that are not enumerable
    function getNftInfo()
        external
        view
        returns (bool isSupportPower, uint256 individualPower, uint256 totalSupply);

    /// @notice The function for getting max locked amount of a user
    /// @param voter the address of voter
    /// @return `max locked amount`
    function maxLockedAmount(address voter) external view returns (uint256);

    /// @notice The function for getting token balance of a user
    /// @param voter the address of voter
    /// @param voteType the type of vote
    /// @return balance the total balance with delegations
    /// @return ownedBalance the user balance that is not deposited to the contract
    function tokenBalance(
        address voter,
        IGovPool.VoteType voteType
    ) external view returns (uint256 balance, uint256 ownedBalance);

    /// @notice The function for getting nft balance of a user
    /// @param voter the address of voter
    /// @param voteType the type of vote
    /// @return balance the total balance with delegations
    /// @return ownedBalance the number of nfts that are not deposited to the contract
    function nftBalance(
        address voter,
        IGovPool.VoteType voteType
    ) external view returns (uint256 balance, uint256 ownedBalance);

    /// @notice The function for getting nft ids of a user
    /// @param voter the address of voter
    /// @param voteType the type of vote
    /// @return nfts the array of owned nft ids
    /// @return ownedLength the number of nfts that are not deposited to the contract
    function nftExactBalance(
        address voter,
        IGovPool.VoteType voteType
    ) external view returns (uint256[] memory nfts, uint256 ownedLength);

    /// @notice The function for getting total power of nfts by ids
    /// @param nftIds the array of nft ids
    /// @param voteType the type of vote
    /// @param voter the address of user
    /// @param perNftPowerArray should the nft raw powers array be returned
    /// @return nftPower the total total power of nfts
    /// @return perNftPower the array of nft powers, bounded with nftIds by index
    function getTotalNftsPower(
        uint256[] memory nftIds,
        IGovPool.VoteType voteType,
        address voter,
        bool perNftPowerArray
    ) external view returns (uint256 nftPower, uint256[] memory perNftPower);

    /// @notice The function for getting total voting power of the contract
    /// @return power total power
    function getTotalPower() external view returns (uint256 power);

    /// @notice The function to define if voter is able to create a proposal. Includes micropool balance
    /// @param voter the address of voter
    /// @param voteType the type of vote
    /// @param requiredVotes the required voting power
    /// @return `true` - can participate, `false` - can't participate
    function canCreate(
        address voter,
        IGovPool.VoteType voteType,
        uint256 requiredVotes
    ) external view returns (bool);

    /// @notice The function for getting voting power of users
    /// @param users the array of users addresses
    /// @param voteTypes the array of vote types
    /// @param perNftPowerArray should the nft powers array be calculated
    /// @return votingPowers the array of VotingPowerView structs
    function votingPower(
        address[] calldata users,
        IGovPool.VoteType[] calldata voteTypes,
        bool perNftPowerArray
    ) external view returns (VotingPowerView[] memory votingPowers);

    /// @notice The function for getting voting power after the formula
    /// @param voter the address of the voter
    /// @param amount the amount of tokens
    /// @param nftIds the array of nft ids
    /// @return personalPower the personal voting power after the formula
    /// @return fullPower the personal plus delegated voting power after the formula
    function transformedVotingPower(
        address voter,
        uint256 amount,
        uint256[] calldata nftIds
    ) external view returns (uint256 personalPower, uint256 fullPower);

    /// @notice The function for getting information about user's delegations
    /// @param user the address of user
    /// @param perNftPowerArray should the nft powers array be calculated
    /// @return power the total delegated power
    /// @return delegationsInfo the array of DelegationInfoView structs
    function delegations(
        address user,
        bool perNftPowerArray
    ) external view returns (uint256 power, DelegationInfoView[] memory delegationsInfo);

    /// @notice The function for getting information about funds that can be withdrawn
    /// @param voter the address of voter
    /// @param lockedProposals the array of ids of locked proposals
    /// @param unlockedNfts the array of unlocked nfts
    /// @return withdrawableTokens the tokens that can we withdrawn
    /// @return withdrawableNfts the array of nfts that can we withdrawn
    function getWithdrawableAssets(
        address voter,
        uint256[] calldata lockedProposals,
        uint256[] calldata unlockedNfts
    ) external view returns (uint256 withdrawableTokens, uint256[] memory withdrawableNfts);

    /// @notice The function for getting the total delegated power by the delegator and the delegatee
    /// @param delegator the address of the delegator
    /// @param delegatee the address of the delegatee
    /// @return delegatedPower the total delegated power
    function getDelegatedAssetsPower(
        address delegator,
        address delegatee
    ) external view returns (uint256 delegatedPower);

    /// @notice The function for getting the wrapped token amount, not covered by ether
    /// @param value the ether value sent alongside the call
    /// @param amount the total amount of wrapped ether with 18 decimals
    /// @return nativeAmount the amount of wrapped ether with native decimals minus ether value
    function getAmountWithNativeDecimals(
        uint256 value,
        uint256 amount
    ) external view returns (uint256 nativeAmount);
}
