// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

/**
 * The contract for the additional proposal with custom settings.
 * This contract acts as a marketplace to provide DAO pools with the ability to sell their own ERC20 tokens.
 */
interface ITokenSaleProposal {
    /// @notice The enum that represents the type of requirements to participate in the tier
    /// @param DAOVotes indicates that the user must have the required voting power
    /// @param Whitelist indicates that the user must be included in the whitelist of the tier
    /// @param BABT indicates that the user must own the BABT token
    /// @param TokenLock indicates that the user must lock a specific amount of tokens in the tier
    /// @param NftLock indicates that the user must lock an nft in the tier
    /// @param MerkleWhitelist indicates that the user must have whitelist Merkle Proofs
    enum ParticipationType {
        DAOVotes,
        Whitelist,
        BABT,
        TokenLock,
        NftLock,
        MerkleWhitelist
    }

    /// @notice Metadata of the tier that is part of the initial tier parameters
    /// @param name the name of the tier
    /// @param description the description of the tier
    struct TierMetadata {
        string name;
        string description;
    }

    /// @notice Vesting parameters that are part of the initial tier parameters
    /// @param vestingPercentage percentage of the purchased token amount that goes to vesting
    /// @param vestingDuration how long vesting lasts from the time of the token purchase
    /// @param cliffPeriod how long the user cannot make a vesting withdrawal from the time of the token purchase
    /// @param unlockStep the tick step with which funds from the vesting are given to the buyer
    struct VestingSettings {
        uint256 vestingPercentage;
        uint64 vestingDuration;
        uint64 cliffPeriod;
        uint64 unlockStep;
    }

    /// @notice Participation details that are part of the initial tier parameters
    /// @param participationType the type of requirements to participate in the tier
    /// @param data the additional data associated with the participation requirements
    struct ParticipationDetails {
        ParticipationType participationType;
        bytes data;
    }

    /// @notice Initial tier parameters
    /// @param metadata metadata of the tier (see TierMetadata)
    /// @param totalTokenProvided total supply of tokens provided for the tier
    /// @param saleStartTime start time of token sales
    /// @param saleEndTime end time of token sales
    /// @param claimLockDuration the period of time between the end of the token sale and the non-vesting tokens claiming
    /// @param saleTokenAddress address of the token being sold
    /// @param purchaseTokenAddresses tokens, that can be used for purchasing token of the proposal
    /// @param exchangeRates exchange rates of other tokens to the token of TokenSaleProposal. Must disregard tokens decimals.
    /// If you want to sell 1 BTC for 1 ETH, exchangeRate has to be 10**25
    /// @param minAllocationPerUser minimal allocation of tokens per one user
    /// @param maxAllocationPerUser maximal allocation of tokens per one user
    /// @param vestingSettings settings for managing tokens vesting (unlocking). While tokens are locked investors won`t be able to withdraw them
    /// @param participationDetails the list of participation requirement parameters
    struct TierInitParams {
        TierMetadata metadata;
        uint256 totalTokenProvided;
        uint64 saleStartTime;
        uint64 saleEndTime;
        uint64 claimLockDuration;
        address saleTokenAddress;
        address[] purchaseTokenAddresses;
        uint256[] exchangeRates;
        uint256 minAllocationPerUser;
        uint256 maxAllocationPerUser;
        VestingSettings vestingSettings;
        ParticipationDetails[] participationDetails;
    }

    /// @notice Vesting tier-related parameters
    /// @param vestingStartTime the start time of the vesting when the cliff period ends
    /// @param vestingEndTime the end time of the vesting
    struct VestingTierInfo {
        uint64 vestingStartTime;
        uint64 vestingEndTime;
    }

    /// @notice Dynamic tier parameters
    /// @param isOff whether the tier is off
    /// @param totalSold how many tokens were sold
    /// @param uri whitelist uri
    /// @param vestingTierInfo vesting tier-related params
    struct TierInfo {
        bool isOff;
        uint256 totalSold;
        string uri;
        VestingTierInfo vestingTierInfo;
    }

    /// @notice Tier additional parameters
    /// @param merkleRoot root of Merkle Tree for whitelist (zero if Merkle proofs turned off)
    /// @param merkleUri merkle whitlist uri
    /// @param lastModified proposal was last modified on this block number. 0 for the new tiers
    struct TierAdditionalInfo {
        bytes32 merkleRoot;
        string merkleUri;
        uint256 lastModified;
    }

    /// @notice Purchase parameters
    /// @param spentAmounts matching purchase token addresses with spent amounts
    /// @param claimTotalAmount the total amount to be claimed
    /// @param isClaimed the boolean indicating whether the purchase has been claimed or not
    /// @param lockedTokens matching user locked tokens to locked amounts
    /// @param lockedNftAddresses the list of nft addresses locked by the user
    /// @param lockedNfts the list of nft ids locked by the user
    struct PurchaseInfo {
        EnumerableMap.AddressToUintMap spentAmounts;
        uint256 claimTotalAmount;
        bool isClaimed;
        EnumerableMap.AddressToUintMap lockedTokens;
        EnumerableSet.AddressSet lockedNftAddresses;
        mapping(address => EnumerableSet.UintSet) lockedNfts;
    }

    /// @notice Purchase parameters. This struct is used in view functions as part of a return argument
    /// @param isClaimed the boolean indicating whether non-vesting tokens have been claimed or not
    /// @param canClaim the boolean indication whether the user can claim non-vesting tokens
    /// @param claimUnlockTime the time the user can claim its non-vesting tokens
    /// @param claimTotalAmount the total amount of tokens to be claimed
    /// @param boughtTotalAmount the total amount of tokens user bought including vesting and non-vesting tokens
    /// @param lockedTokenAddresses the list of locked token addresses
    /// @param lockedTokenAmounts the list of locked token amounts
    /// @param lockedNftAddresses the list of locked nft addresses
    /// @param lockedNftIds the list of locked nft ids
    /// @param purchaseTokenAddresses the list of purchase token addresses
    /// @param purchaseTokenAmounts the list of purchase token amounts
    struct PurchaseView {
        bool isClaimed;
        bool canClaim;
        uint64 claimUnlockTime;
        uint256 claimTotalAmount;
        uint256 boughtTotalAmount;
        address[] lockedTokenAddresses;
        uint256[] lockedTokenAmounts;
        address[] lockedNftAddresses;
        uint256[][] lockedNftIds;
        address[] purchaseTokenAddresses;
        uint256[] purchaseTokenAmounts;
    }

    /// @notice Vesting user-related parameters
    /// @param latestVestingWithdraw the latest timestamp of the vesting withdrawal
    /// @param vestingTotalAmount the total amount of user vesting tokens
    /// @param vestingWithdrawnAmount the total amount of tokens user has withdrawn from vesting
    struct VestingUserInfo {
        uint64 latestVestingWithdraw;
        uint256 vestingTotalAmount;
        uint256 vestingWithdrawnAmount;
    }

    /// @notice Vesting user-related parameters. This struct is used in view functions as part of a return argument
    /// @param latestVestingWithdraw the latest timestamp of the vesting withdrawal
    /// @param nextUnlockTime the next time the user will receive vesting funds. It is zero if there are no more locked tokens
    /// @param nextUnlockAmount the token amount which will be unlocked in the next unlock time
    /// @param vestingTotalAmount the total amount of user vesting tokens
    /// @param vestingWithdrawnAmount the total amount of tokens user has withdrawn from vesting
    /// @param amountToWithdraw the vesting token amount which can be withdrawn in the current time
    /// @param lockedAmount the vesting token amount which is locked in the current time
    struct VestingUserView {
        uint64 latestVestingWithdraw;
        uint64 nextUnlockTime;
        uint256 nextUnlockAmount;
        uint256 vestingTotalAmount;
        uint256 vestingWithdrawnAmount;
        uint256 amountToWithdraw;
        uint256 lockedAmount;
    }

    /// @notice Participation parameters. Users should meet all the requirements in order to participate in the tier
    /// @param isWhitelisted the boolean indicating whether the tier requires whitelist
    /// @param isBABTed the boolean indicating whether the tier requires BABT token
    /// @param requiredDaoVotes the required amount of DAO votes
    /// @param requiredTokenLock matching token address to required lock amounts
    /// @param requiredNftLock matching nft address to required lock amounts
    struct ParticipationInfo {
        bool isWhitelisted;
        bool isBABTed;
        uint256 requiredDaoVotes;
        EnumerableMap.AddressToUintMap requiredTokenLock;
        EnumerableMap.AddressToUintMap requiredNftLock;
    }

    /// @notice Commplete list of participation parameters
    /// @param isWhitelisted the boolean indicating whether the tier requires whitelist
    /// @param isBABTed the boolean indicating whether the tier requires BABT token
    /// @param requiredDaoVotes the required amount of DAO votes
    /// @param requiredTokenAddresses list of required tokens to lock
    /// @param requiredTokenAmounts list of required amounts of token to lock
    /// @param requiredNftAddresses list of required nfts to lock
    /// @param requiredNftAmounts list of required amounts of nft to lock
    /// @param merkleRoot root of Merkle Tree for whitelist (zero if Merkle proofs turned off)
    /// @param merkleUri merkle whitlist uri
    struct ParticipationInfoView {
        bool isWhitelisted;
        bool isBABTed;
        uint256 requiredDaoVotes;
        address[] requiredTokenAddresses;
        uint256[] requiredTokenAmounts;
        address[] requiredNftAddresses;
        uint256[] requiredNftAmounts;
        bytes32 merkleRoot;
        string merkleUri;
    }

    /// @notice User parameters
    /// @param purchaseInfo the information about the user purchase
    /// @param vestingUserInfo the information about the user vesting
    struct UserInfo {
        PurchaseInfo purchaseInfo;
        VestingUserInfo vestingUserInfo;
    }

    /// @notice User parameters. This struct is used in view functions as a return argument
    /// @param canParticipate the boolean indicating whether the user is whitelisted in the corresponding tier
    /// @param purchaseView the information about the user purchase
    /// @param vestingUserView the information about the user vesting
    struct UserView {
        bool canParticipate;
        PurchaseView purchaseView;
        VestingUserView vestingUserView;
    }

    /// @notice Tier parameters
    /// @param tierInitParams the initial tier parameters
    /// @param tierInfo the information about the tier
    /// @param participationInfo the information about participation requirements
    /// @param rates the mapping of token addresses to their exchange rates
    /// @param users the mapping of user addresses to their infos
    /// @param tierAdditionalInfo the information about additional tier properties
    struct Tier {
        TierInitParams tierInitParams;
        TierInfo tierInfo;
        ParticipationInfo participationInfo;
        mapping(address => uint256) rates;
        mapping(address => UserInfo) users;
        TierAdditionalInfo tierAdditionalInfo;
    }

    /// @notice Tier parameters. This struct is used in view functions as a return argument
    /// @param tierInitParams the initial tier parameters
    /// @param tierInfo the information about the tier
    struct TierView {
        TierInitParams tierInitParams;
        TierInfo tierInfo;
        TierAdditionalInfo tierAdditionalInfo;
    }

    /// @notice Whitelisting request parameters. This struct is used as an input parameter to the whitelist update function
    /// @param tierId the id of the tier
    /// @param users the list of the users to be whitelisted
    /// @param uri tokens metadata uri
    struct WhitelistingRequest {
        uint256 tierId;
        address[] users;
        string uri;
    }

    /// @notice This function is used to get id (index) of the latest tier of the token sale
    /// @return the id of the latest tier
    function latestTierId() external view returns (uint256);

    /// @notice This function is used for tiers creation
    /// @param tiers parameters of tiers
    function createTiers(TierInitParams[] calldata tiers) external;

    /// @notice This function is used to modify tier
    /// @param tierId the id of tier
    /// @param newSettings the new tier settings
    function modifyTier(uint256 tierId, TierInitParams calldata newSettings) external;

    /// @notice This function is used for changing participation settings of the tier
    /// @param tierId id of the tier to modify
    /// @param newSettings list of participation parameters to set
    function changeParticipationDetails(
        uint256 tierId,
        ParticipationDetails[] calldata newSettings
    ) external;

    /// @notice This function is used to add users to the whitelist of tier
    /// @param requests requests for adding users to the whitelist
    function addToWhitelist(WhitelistingRequest[] calldata requests) external;

    /// @notice This function is used to set given tiers inactive
    /// @param tierIds tier ids to set inactive
    function offTiers(uint256[] calldata tierIds) external;

    /// @notice This function is used to return to the DAO treasury tokens that have not been purchased during sale
    /// @param tierIds tier ids to recover from
    function recover(uint256[] calldata tierIds) external;

    /// @notice This function is used to withdraw non-vesting tokens from given tiers
    /// @param tierIds tier ids to make withdrawals from
    function claim(uint256[] calldata tierIds) external;

    /// @notice This function is used to withdraw vesting tokens from given tiers
    /// @param tierIds tier ids to make withdrawals from
    function vestingWithdraw(uint256[] calldata tierIds) external;

    /// @notice This function is used to purchase tokens in the given tier
    /// @param tierId the id of the tier where tokens will be purchased
    /// @param tokenToBuyWith the token that will be used (exchanged) to purchase token on the token sale
    /// @param amount the amount of the token to be used for this exchange
    /// @param proof the merkle proof for merkle whitelist. Could be empty if whitelist is disabled
    function buy(
        uint256 tierId,
        address tokenToBuyWith,
        uint256 amount,
        bytes32[] calldata proof
    ) external payable;

    /// @notice This function is used to lock the specified amount of tokens to participate in the given tier
    /// @param tierId the id of the tier to lock the tokens for
    /// @param tokenToLock the address of the token to be locked
    /// @param amountToLock the number of tokens to be locked
    function lockParticipationTokens(
        uint256 tierId,
        address tokenToLock,
        uint256 amountToLock
    ) external payable;

    /// @notice This function is used to lock the specified nft to participate in the given tier
    /// @param tierId the id of the tier to lock the nft for
    /// @param nftToLock the address of nft to be locked
    /// @param nftIdsToLock the list of nft ids to be locked
    function lockParticipationNft(
        uint256 tierId,
        address nftToLock,
        uint256[] calldata nftIdsToLock
    ) external;

    /// @notice This function is used to unlock participation tokens
    /// @param tierId the id of the tier to unlock the tokens for
    /// @param tokenToUnlock the address of the token to be unlocked
    /// @param amountToUnlock the number of tokens to be unlocked
    function unlockParticipationTokens(
        uint256 tierId,
        address tokenToUnlock,
        uint256 amountToUnlock
    ) external;

    /// @notice This function is used to unlock the participation nft
    /// @param tierId the id of the tier to unlock the nft for
    /// @param nftToUnlock the address of nft to be unlocked
    /// @param nftIdsToUnlock the list of nft ids to be unlocked
    function unlockParticipationNft(
        uint256 tierId,
        address nftToUnlock,
        uint256[] calldata nftIdsToUnlock
    ) external;

    /// @notice This function is used to get amount of `TokenSaleProposal` tokens that can be purchased
    /// @param user the address of the user that purchases tokens
    /// @param tierId the id of the tier in which tokens are purchased
    /// @param tokenToBuyWith the token which is used for exchange
    /// @param amount the token amount used for exchange
    /// @param proof the merkle proof for merkle whitelist. Could be empty if whitelist is disabled
    /// @return expected sale token amount
    function getSaleTokenAmount(
        address user,
        uint256 tierId,
        address tokenToBuyWith,
        uint256 amount,
        bytes32[] calldata proof
    ) external view returns (uint256);

    /// @notice This function is used to get information about the amount of non-vesting tokens that user can withdraw (that are unlocked) from given tiers
    /// @param user the address of the user
    /// @param tierIds the array of tier ids
    /// @return claimAmounts the array of token amounts that can be withdrawn from each tier
    function getClaimAmounts(
        address user,
        uint256[] calldata tierIds
    ) external view returns (uint256[] memory claimAmounts);

    /// @notice This function is used to get information about the amount of vesting tokens that user can withdraw (that are unlocked) from given tiers
    /// @param user the address of the user
    /// @param tierIds the array of tier ids
    /// @return vestingWithdrawAmounts the array of token amounts that can be withdrawn from each tier
    function getVestingWithdrawAmounts(
        address user,
        uint256[] calldata tierIds
    ) external view returns (uint256[] memory vestingWithdrawAmounts);

    /// @notice This function is used to get amount of tokens that have not been purchased during sale in given tiers and can be returned to DAO treasury
    /// @param tierIds the array of tier ids
    /// @return recoveringAmounts the array of token amounts that can be returned to DAO treasury in each tier
    function getRecoverAmounts(
        uint256[] calldata tierIds
    ) external view returns (uint256[] memory recoveringAmounts);

    /// @notice This function is used to get a list of tiers
    /// @param offset the offset of the list
    /// @param limit the limit for amount of elements in the list
    /// @return tierViews the list of tier views
    function getTierViews(
        uint256 offset,
        uint256 limit
    ) external view returns (TierView[] memory tierViews);

    /// @notice This function is used to get participation settings of a tier
    /// @param tierId the tier id
    /// @return tierParticipationDetails the list of tier participation settings
    function getParticipationDetails(
        uint256 tierId
    ) external view returns (ParticipationInfoView memory tierParticipationDetails);

    /// @notice This function is used to get user's infos from tiers
    /// @param user the address of the user whose infos are required
    /// @param tierIds the list of tier ids to get infos from
    /// @return userViews the list of user views
    /// @param proofs the list of merkle proofs
    function getUserViews(
        address user,
        uint256[] calldata tierIds,
        bytes32[][] calldata proofs
    ) external view returns (UserView[] memory userViews);
}
