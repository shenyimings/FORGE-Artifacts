// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";

import "@solarity/solidity-lib/contracts-registry/AbstractDependant.sol";
import "@solarity/solidity-lib/utils/BlockGuard.sol";

import "../interfaces/gov/settings/IGovSettings.sol";
import "../interfaces/gov/user-keeper/IGovUserKeeper.sol";
import "../interfaces/gov/validators/IGovValidators.sol";
import "../interfaces/gov/IGovPool.sol";
import "../interfaces/gov/ERC721/experts/IERC721Expert.sol";
import "../interfaces/core/IContractsRegistry.sol";
import "../interfaces/core/ICoreProperties.sol";
import "../interfaces/core/ISBT721.sol";
import "../interfaces/factory/IPoolFactory.sol";

import "../libs/gov/gov-user-keeper/GovUserKeeperLocal.sol";
import "../libs/gov/gov-pool/GovPoolView.sol";
import "../libs/gov/gov-pool/GovPoolCreate.sol";
import "../libs/gov/gov-pool/GovPoolRewards.sol";
import "../libs/gov/gov-pool/GovPoolVote.sol";
import "../libs/gov/gov-pool/GovPoolUnlock.sol";
import "../libs/gov/gov-pool/GovPoolExecute.sol";
import "../libs/gov/gov-pool/GovPoolMicropool.sol";
import "../libs/gov/gov-pool/GovPoolCredit.sol";
import "../libs/gov/gov-pool/GovPoolOffchain.sol";
import "../libs/math/MathHelper.sol";

import "../core/Globals.sol";

contract GovPool is
    IGovPool,
    AbstractDependant,
    ERC721HolderUpgradeable,
    ERC1155HolderUpgradeable,
    Multicall,
    BlockGuard
{
    using MathHelper for uint256;
    using Math for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using GovPoolOffchain for *;
    using GovUserKeeperLocal for *;
    using GovPoolView for *;
    using GovPoolCreate for *;
    using GovPoolRewards for *;
    using GovPoolVote for *;
    using GovPoolUnlock for *;
    using GovPoolExecute for *;
    using GovPoolCredit for *;
    using GovPoolMicropool for *;
    using DecimalsConverter for *;
    using TokenBalance for address;

    address internal _nftMultiplier;
    IERC721Expert internal _expertNft;
    IERC721Expert internal _dexeExpertNft;
    ISBT721 internal _babt;

    IGovSettings internal _govSettings;
    IGovUserKeeper internal _govUserKeeper;
    IGovValidators internal _govValidators;
    address internal _poolRegistry;
    address internal _votePowerContract;

    ICoreProperties public coreProperties;

    string public descriptionURL;
    string public name;

    bool public onlyBABTHolders;

    uint256 public latestProposalId;
    uint256 public deployerBABTid;

    CreditInfo internal _creditInfo;
    OffChain internal _offChain;

    mapping(uint256 => Proposal) internal _proposals; // proposalId => info
    mapping(address => UserInfo) internal _userInfos; // user => info

    string private constant DEPOSIT_WITHDRAW = "DEPOSIT_WITHDRAW";
    string private constant DELEGATE_UNDELEGATE = "DELEGATE_UNDELEGATE";
    string private constant DELEGATE_UNDELEGATE_TREASURY = "DELEGATE_UNDELEGATE_TREASURY";

    event Delegated(address from, address to, uint256 amount, uint256[] nfts, bool isDelegate);
    event DelegatedTreasury(address to, uint256 amount, uint256[] nfts, bool isDelegate);
    event Deposited(uint256 amount, uint256[] nfts, address sender);
    event Withdrawn(uint256 amount, uint256[] nfts, address sender);

    modifier onlyThis() {
        _onlyThis();
        _;
    }

    modifier onlyBABTHolder() {
        _onlyBABTHolder();
        _;
    }

    modifier onlyValidatorContract() {
        _onlyValidatorContract();
        _;
    }

    function __GovPool_init(
        Dependencies calldata govPoolDeps,
        address _verifier,
        bool _onlyBABTHolders,
        uint256 _deployerBABTid,
        string calldata _descriptionURL,
        string calldata _name
    ) external initializer {
        _govSettings = IGovSettings(govPoolDeps.settingsAddress);
        _govUserKeeper = IGovUserKeeper(govPoolDeps.userKeeperAddress);
        _govValidators = IGovValidators(govPoolDeps.validatorsAddress);
        _expertNft = IERC721Expert(govPoolDeps.expertNftAddress);
        _nftMultiplier = govPoolDeps.nftMultiplierAddress;

        _changeVotePower(govPoolDeps.votePowerAddress);

        onlyBABTHolders = _onlyBABTHolders;
        deployerBABTid = _deployerBABTid;

        descriptionURL = _descriptionURL;
        name = _name;

        _offChain.verifier = _verifier;
    }

    function setDependencies(address contractsRegistry, bytes memory) public override dependant {
        IContractsRegistry registry = IContractsRegistry(contractsRegistry);

        coreProperties = ICoreProperties(registry.getCorePropertiesContract());
        _babt = ISBT721(registry.getBABTContract());
        _dexeExpertNft = IERC721Expert(registry.getDexeExpertNftContract());
        _poolRegistry = registry.getPoolRegistryContract();

        IGovUserKeeper(_govUserKeeper).setDependencies(contractsRegistry, bytes(""));
    }

    function unlock(address user) external override onlyBABTHolder {
        _unlock(user);
    }

    function execute(uint256 proposalId) external override onlyBABTHolder {
        _updateRewards(proposalId, msg.sender, RewardType.Execute);

        _proposals.execute(proposalId);
    }

    function deposit(
        uint256 amount,
        uint256[] calldata nftIds
    ) external payable override onlyBABTHolder {
        require(amount > 0 || nftIds.length > 0, "Gov: empty deposit");

        _lockBlock(DEPOSIT_WITHDRAW, msg.sender);

        if (amount != 0 || msg.value != 0) {
            _govUserKeeper.depositTokens{value: msg.value}(msg.sender, msg.sender, amount);
        }

        _govUserKeeper.depositNfts.exec(msg.sender, nftIds);

        emit Deposited(amount, nftIds, msg.sender);
    }

    function createProposal(
        string calldata _descriptionURL,
        ProposalAction[] calldata actionsOnFor,
        ProposalAction[] calldata actionsOnAgainst
    ) external override onlyBABTHolder {
        uint256 proposalId = _createProposal(_descriptionURL, actionsOnFor, actionsOnAgainst);

        _updateRewards(proposalId, msg.sender, RewardType.Create);
    }

    function createProposalAndVote(
        string calldata _descriptionURL,
        ProposalAction[] calldata actionsOnFor,
        ProposalAction[] calldata actionsOnAgainst,
        uint256 voteAmount,
        uint256[] calldata voteNftIds
    ) external override onlyBABTHolder {
        uint256 proposalId = _createProposal(_descriptionURL, actionsOnFor, actionsOnAgainst);

        _updateRewards(proposalId, msg.sender, RewardType.Create);

        _unlock(msg.sender);

        _vote(proposalId, voteAmount, voteNftIds, true);
    }

    function moveProposalToValidators(uint256 proposalId) external override onlyBABTHolder {
        _proposals.moveProposalToValidators(proposalId);

        _updateRewards(proposalId, msg.sender, RewardType.Execute);
    }

    function vote(
        uint256 proposalId,
        bool isVoteFor,
        uint256 voteAmount,
        uint256[] calldata voteNftIds
    ) external override onlyBABTHolder {
        _unlock(msg.sender);

        _vote(proposalId, voteAmount, voteNftIds, isVoteFor);
    }

    function cancelVote(uint256 proposalId) external override onlyBABTHolder {
        _unlock(msg.sender);

        _proposals.cancelVote(_userInfos, proposalId);
    }

    function withdraw(
        address receiver,
        uint256 amount,
        uint256[] calldata nftIds
    ) external override onlyBABTHolder {
        require(amount > 0 || nftIds.length > 0, "Gov: empty withdrawal");

        _checkBlock(DEPOSIT_WITHDRAW, msg.sender);

        _unlock(msg.sender);

        _govUserKeeper.withdrawTokens.exec(receiver, amount);
        _govUserKeeper.withdrawNfts.exec(receiver, nftIds);

        emit Withdrawn(amount, nftIds, receiver);
    }

    function delegate(
        address delegatee,
        uint256 amount,
        uint256[] calldata nftIds
    ) external override onlyBABTHolder {
        require(amount > 0 || nftIds.length > 0, "Gov: empty delegation");
        require(msg.sender != delegatee, "Gov: delegator's equal delegatee");

        _lockBlock(DELEGATE_UNDELEGATE, msg.sender);

        _unlock(msg.sender);
        _unlock(delegatee);

        _updateNftPowers(nftIds);

        _govUserKeeper.delegateTokens.exec(delegatee, amount);
        _govUserKeeper.delegateNfts.exec(delegatee, nftIds);

        _userInfos.saveDelegationInfo(delegatee);

        _revoteDelegated(delegatee, VoteType.MicropoolVote);

        emit Delegated(msg.sender, delegatee, amount, nftIds, true);
    }

    function delegateTreasury(
        address delegatee,
        uint256 amount,
        uint256[] calldata nftIds
    ) external payable override onlyThis {
        require(amount > 0 || nftIds.length > 0, "Gov: empty delegation");
        require(getExpertStatus(delegatee), "Gov: delegatee is not an expert");

        _lockBlock(DELEGATE_UNDELEGATE_TREASURY, delegatee);

        _unlock(delegatee);

        if (amount != 0 || msg.value != 0) {
            address token = _govUserKeeper.tokenAddress();
            uint256 amountWithNativeDecimals = _govUserKeeper.getAmountWithNativeDecimals(
                msg.value,
                amount
            );

            if (amountWithNativeDecimals != 0) {
                IERC20(token).safeTransfer(address(_govUserKeeper), amountWithNativeDecimals);
            }

            _govUserKeeper.delegateTokensTreasury{value: msg.value}(delegatee, amount);
        }

        if (nftIds.length != 0) {
            IERC721 nft = IERC721(_govUserKeeper.nftAddress());

            for (uint256 i; i < nftIds.length; i++) {
                nft.safeTransferFrom(address(this), address(_govUserKeeper), nftIds[i]);
            }

            _updateNftPowers(nftIds);

            _govUserKeeper.delegateNftsTreasury(delegatee, nftIds);
        }

        _revoteDelegated(delegatee, VoteType.TreasuryVote);

        emit DelegatedTreasury(delegatee, amount, nftIds, true);
    }

    function undelegate(
        address delegatee,
        uint256 amount,
        uint256[] calldata nftIds
    ) external override onlyBABTHolder {
        require(amount > 0 || nftIds.length > 0, "Gov: empty undelegation");

        _checkBlock(DELEGATE_UNDELEGATE, msg.sender);

        _unlock(delegatee);

        _updateNftPowers(nftIds);

        _govUserKeeper.undelegateTokens.exec(delegatee, amount);
        _govUserKeeper.undelegateNfts.exec(delegatee, nftIds);

        _userInfos.saveDelegationInfo(delegatee);

        _revoteDelegated(delegatee, VoteType.MicropoolVote);

        emit Delegated(msg.sender, delegatee, amount, nftIds, false);
    }

    function undelegateTreasury(
        address delegatee,
        uint256 amount,
        uint256[] calldata nftIds
    ) external override onlyThis {
        require(amount > 0 || nftIds.length > 0, "Gov: empty undelegation");

        _checkBlock(DELEGATE_UNDELEGATE_TREASURY, delegatee);

        _unlock(delegatee);

        _updateNftPowers(nftIds);

        _govUserKeeper.undelegateTokensTreasury.exec(delegatee, amount);
        _govUserKeeper.undelegateNftsTreasury.exec(delegatee, nftIds);

        _revoteDelegated(delegatee, VoteType.TreasuryVote);

        emit DelegatedTreasury(delegatee, amount, nftIds, false);
    }

    function claimRewards(
        uint256[] calldata proposalIds,
        address user
    ) external override onlyBABTHolder {
        for (uint256 i; i < proposalIds.length; i++) {
            uint256 proposalId = proposalIds[i];

            _updateRewards(proposalId, user, RewardType.Vote);

            _userInfos.claimReward(_proposals, proposalId, user);
        }
    }

    function claimMicropoolRewards(
        uint256[] calldata proposalIds,
        address delegator,
        address delegatee
    ) external override onlyBABTHolder {
        for (uint256 i; i < proposalIds.length; i++) {
            uint256 proposalId = proposalIds[i];

            _updateRewards(proposalId, delegatee, RewardType.Vote);

            _userInfos.claim(_proposals, proposalId, delegator, delegatee);
        }
    }

    function changeVotePower(address votePower) external override onlyThis {
        _changeVotePower(votePower);
    }

    function editDescriptionURL(string calldata newDescriptionURL) external override onlyThis {
        descriptionURL = newDescriptionURL;
    }

    function changeVerifier(address newVerifier) external override onlyThis {
        _offChain.verifier = newVerifier;
    }

    function changeBABTRestriction(bool onlyBABT) external override onlyThis {
        onlyBABTHolders = onlyBABT;
    }

    function setNftMultiplierAddress(address nftMultiplierAddress) external override onlyThis {
        _nftMultiplier = nftMultiplierAddress;
    }

    function setCreditInfo(
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external override onlyThis {
        _creditInfo.setCreditInfo(tokens, amounts);
    }

    function transferCreditAmount(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address destination
    ) external override onlyValidatorContract {
        _creditInfo.transferCreditAmount(tokens, amounts, destination);
    }

    function saveOffchainResults(
        string calldata resultsHash,
        bytes calldata signature
    ) external override onlyBABTHolder {
        _offChain.saveOffchainResults(resultsHash, signature);

        _updateRewards(0, msg.sender, RewardType.SaveOffchainResults);
    }

    receive() external payable {}

    function getProposalState(uint256 proposalId) external view override returns (ProposalState) {
        return _proposals.getProposalState(proposalId);
    }

    function getHelperContracts()
        external
        view
        override
        returns (
            address settings,
            address userKeeper,
            address validators,
            address poolRegistry,
            address votePower
        )
    {
        return (
            address(_govSettings),
            address(_govUserKeeper),
            address(_govValidators),
            _poolRegistry,
            _votePowerContract
        );
    }

    function getNftContracts()
        external
        view
        override
        returns (address nftMultiplier, address expertNft, address dexeExpertNft, address babt)
    {
        return (_nftMultiplier, address(_expertNft), address(_dexeExpertNft), address(_babt));
    }

    function getProposals(
        uint256 offset,
        uint256 limit
    ) external view override returns (ProposalView[] memory proposals) {
        return _proposals.getProposals(offset, limit);
    }

    function getUserActiveProposalsCount(address user) external view override returns (uint256) {
        return _userInfos[user].votedInProposals.length();
    }

    function getProposalRequiredQuorum(
        uint256 proposalId
    ) external view override returns (uint256) {
        ProposalCore storage core = _proposals[proposalId].core;

        if (core.voteEnd == 0) {
            return 0;
        }

        return _govUserKeeper.getTotalPower().ratio(core.settings.quorum, PERCENTAGE_100);
    }

    function getTotalVotes(
        uint256 proposalId,
        address voter,
        VoteType voteType
    ) external view override returns (uint256, uint256, uint256, bool) {
        require(voteType != VoteType.DelegatedVote, "Gov: use personal");

        ProposalCore storage core = _proposals[proposalId].core;
        VoteInfo storage info = _userInfos[voter].voteInfos[proposalId];

        return (
            core.rawVotesFor,
            core.rawVotesAgainst,
            info.rawVotes[voteType].totalVoted,
            info.isVoteFor
        );
    }

    function getUserVotes(
        uint256 proposalId,
        address voter,
        VoteType voteType
    ) external view override returns (VoteInfoView memory voteInfo) {
        VoteInfo storage info = _userInfos[voter].voteInfos[proposalId];
        RawVote storage rawVote = info.rawVotes[voteType];

        return
            VoteInfoView({
                isVoteFor: info.isVoteFor,
                totalVoted: info.totalVoted,
                tokensVoted: rawVote.tokensVoted,
                totalRawVoted: rawVote.totalVoted,
                nftsVoted: rawVote.nftsVoted.values()
            });
    }

    function getWithdrawableAssets(
        address delegator
    ) external view override returns (uint256 tokens, uint256[] memory nfts) {
        return _userInfos.getWithdrawableAssets(delegator);
    }

    function getPendingRewards(
        address user,
        uint256[] calldata proposalIds
    ) external view override returns (PendingRewardsView memory) {
        return _userInfos.getPendingRewards(_proposals, user, proposalIds);
    }

    function getDelegatorRewards(
        uint256[] calldata proposalIds,
        address delegator,
        address delegatee
    ) external view override returns (DelegatorRewards memory) {
        return _userInfos.getDelegatorRewards(_proposals, proposalIds, delegator, delegatee);
    }

    function getCreditInfo() external view override returns (CreditInfoView[] memory) {
        return _creditInfo.getCreditInfo();
    }

    function getOffchainInfo()
        external
        view
        override
        returns (address validator, string memory resultsHash)
    {
        return (_offChain.verifier, _offChain.resultsHash);
    }

    function getOffchainSignHash(
        string calldata resultHash,
        address user
    ) external view override returns (bytes32) {
        return resultHash.getSignHash(user);
    }

    function getExpertStatus(address user) public view override returns (bool) {
        return _expertNft.isExpert(user) || _dexeExpertNft.isExpert(user);
    }

    function _createProposal(
        string calldata _descriptionURL,
        ProposalAction[] calldata actionsOnFor,
        ProposalAction[] calldata actionsOnAgainst
    ) internal returns (uint256 proposalId) {
        proposalId = ++latestProposalId;

        _proposals.createProposal(_userInfos, _descriptionURL, actionsOnFor, actionsOnAgainst);
    }

    function _vote(
        uint256 proposalId,
        uint256 voteAmount,
        uint256[] calldata voteNftIds,
        bool isVoteFor
    ) internal {
        _updateNftPowers(voteNftIds);

        _proposals.vote(_userInfos, proposalId, voteAmount, voteNftIds, isVoteFor);
    }

    function _revoteDelegated(address delegatee, VoteType voteType) internal {
        _proposals.revoteDelegated(_userInfos, delegatee, voteType);
    }

    function _updateRewards(uint256 proposalId, address user, RewardType rewardType) internal {
        if (rewardType == RewardType.Vote) {
            _userInfos.updateVotingRewards(_proposals, proposalId, user);
        } else if (rewardType == RewardType.SaveOffchainResults) {
            _userInfos.updateOffchainRewards(user);
        } else {
            _userInfos.updateStaticRewards(_proposals, proposalId, user, rewardType);
        }
    }

    function _updateNftPowers(uint256[] calldata nftIds) internal {
        _govUserKeeper.updateNftPowers(nftIds);
    }

    function _unlock(address user) internal {
        _userInfos.unlockInProposals(user);
    }

    function _changeVotePower(address votePower) internal {
        require(votePower != address(0), "Gov: zero vote power contract");

        _votePowerContract = votePower;
    }

    function _onlyThis() internal view {
        require(address(this) == msg.sender, "Gov: not this contract");
    }

    function _onlyValidatorContract() internal view {
        require(address(_govValidators) == msg.sender, "Gov: not the validators contract");
    }

    function _onlyBABTHolder() internal view {
        require(
            !onlyBABTHolders ||
                _babt.balanceOf(msg.sender) > 0 ||
                IPoolRegistry(_poolRegistry).isGovPool(msg.sender),
            "Gov: not BABT holder"
        );
    }
}
