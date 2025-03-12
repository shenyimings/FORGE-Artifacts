// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@solarity/solidity-lib/libs/utils/DecimalsConverter.sol";
import "@solarity/solidity-lib/libs/arrays/Paginator.sol";
import "@solarity/solidity-lib/libs/arrays/ArrayHelper.sol";
import "@solarity/solidity-lib/libs/data-structures/memory/Vector.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

import "../../interfaces/core/IContractsRegistry.sol";
import "../../interfaces/core/INetworkProperties.sol";
import "../../interfaces/gov/user-keeper/IGovUserKeeper.sol";
import "../../interfaces/gov/IGovPool.sol";
import "../../interfaces/gov/ERC721/powers/IERC721Power.sol";

import "../../libs/math/MathHelper.sol";
import "../../libs/gov/gov-user-keeper/GovUserKeeperView.sol";

contract GovUserKeeper is IGovUserKeeper, OwnableUpgradeable, ERC721HolderUpgradeable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using MathHelper for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using ArrayHelper for uint256[];
    using Paginator for EnumerableSet.UintSet;
    using DecimalsConverter for *;
    using GovUserKeeperView for *;
    using Vector for Vector.UintVector;

    address public tokenAddress;
    NFTInfo internal _nftInfo;

    mapping(address => UserInfo) internal _usersInfo; // user => info

    mapping(uint256 => uint256) internal _nftLockedNums; // tokenId => locked num

    address public wethAddress;
    address public networkPropertiesAddress;

    event SetERC20(address token);
    event SetERC721(address token);

    modifier withSupportedToken() {
        _withSupportedToken();
        _;
    }

    modifier withSupportedNft() {
        _withSupportedNft();
        _;
    }

    function __GovUserKeeper_init(
        address _tokenAddress,
        address _nftAddress,
        uint256 individualPower,
        uint256 nftsTotalSupply
    ) external initializer {
        __Ownable_init();
        __ERC721Holder_init();

        require(_tokenAddress != address(0) || _nftAddress != address(0), "GovUK: zero addresses");

        if (_nftAddress != address(0)) {
            _setERC721Address(_nftAddress, individualPower, nftsTotalSupply);
        }

        if (_tokenAddress != address(0)) {
            _setERC20Address(_tokenAddress);
        }
    }

    function setDependencies(address contractsRegistry, bytes memory) external onlyOwner {
        IContractsRegistry registry = IContractsRegistry(contractsRegistry);

        wethAddress = registry.getWETHContract();
        networkPropertiesAddress = registry.getNetworkPropertiesContract();
    }

    function depositTokens(
        address payer,
        address receiver,
        uint256 amount
    ) external payable override onlyOwner withSupportedToken {
        address token = tokenAddress;
        uint256 amountWithNativeDecimals = getAmountWithNativeDecimals(msg.value, amount);

        _handleNative(msg.value, true);

        if (amountWithNativeDecimals > 0) {
            IERC20(token).safeTransferFrom(payer, address(this), amountWithNativeDecimals);
        }

        _usersInfo[receiver].balances[IGovPool.VoteType.PersonalVote].tokens += amount;
    }

    function withdrawTokens(
        address payer,
        address receiver,
        uint256 amount
    ) external override onlyOwner withSupportedToken {
        UserInfo storage payerInfo = _usersInfo[payer];
        BalanceInfo storage payerBalanceInfo = payerInfo.balances[IGovPool.VoteType.PersonalVote];

        uint256 balance = payerBalanceInfo.tokens;
        uint256 maxTokensLocked = payerInfo.maxTokensLocked;

        require(
            amount <= balance.max(maxTokensLocked) - maxTokensLocked,
            "GovUK: can't withdraw this"
        );

        payerBalanceInfo.tokens = balance - amount;

        _sendNativeOrToken(receiver, amount);
    }

    function delegateTokens(
        address delegator,
        address delegatee,
        uint256 amount
    ) external override onlyOwner withSupportedToken {
        UserInfo storage delegatorInfo = _usersInfo[delegator];
        BalanceInfo storage delegatorBalanceInfo = delegatorInfo.balances[
            IGovPool.VoteType.PersonalVote
        ];

        uint256 balance = delegatorBalanceInfo.tokens;
        uint256 maxTokensLocked = delegatorInfo.maxTokensLocked;

        require(amount <= balance.max(maxTokensLocked) - maxTokensLocked, "GovUK: overdelegation");

        delegatorInfo.delegatedBalances[delegatee].tokens += amount;
        delegatorInfo.allDelegatedBalance.tokens += amount;
        delegatorBalanceInfo.tokens = balance - amount;

        _usersInfo[delegatee].balances[IGovPool.VoteType.MicropoolVote].tokens += amount;

        delegatorInfo.delegatees.add(delegatee);
    }

    function delegateTokensTreasury(
        address delegatee,
        uint256 amount
    ) external payable override onlyOwner withSupportedToken {
        _handleNative(msg.value, true);

        _usersInfo[delegatee].balances[IGovPool.VoteType.TreasuryVote].tokens += amount;
    }

    function undelegateTokens(
        address delegator,
        address delegatee,
        uint256 amount
    ) external override onlyOwner withSupportedToken {
        UserInfo storage delegatorInfo = _usersInfo[delegator];

        require(
            amount <= delegatorInfo.delegatedBalances[delegatee].tokens,
            "GovUK: amount exceeds delegation"
        );

        _usersInfo[delegatee].balances[IGovPool.VoteType.MicropoolVote].tokens -= amount;

        delegatorInfo.balances[IGovPool.VoteType.PersonalVote].tokens += amount;
        delegatorInfo.delegatedBalances[delegatee].tokens -= amount;
        delegatorInfo.allDelegatedBalance.tokens -= amount;

        _cleanDelegatee(delegatorInfo, delegatee);
    }

    function undelegateTokensTreasury(
        address delegatee,
        uint256 amount
    ) external override onlyOwner withSupportedToken {
        BalanceInfo storage delegateeBalanceInfo = _usersInfo[delegatee].balances[
            IGovPool.VoteType.TreasuryVote
        ];

        uint256 balance = delegateeBalanceInfo.tokens;

        require(amount <= balance, "GovUK: can't withdraw this");

        delegateeBalanceInfo.tokens = balance - amount;

        _sendNativeOrToken(msg.sender, amount);
    }

    function depositNfts(
        address payer,
        address receiver,
        uint256[] calldata nftIds
    ) external override onlyOwner withSupportedNft {
        EnumerableSet.UintSet storage receiverNftBalance = _usersInfo[receiver]
            .balances[IGovPool.VoteType.PersonalVote]
            .nfts;

        IERC721Power nft = IERC721Power(_nftInfo.nftAddress);

        for (uint256 i; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];

            nft.safeTransferFrom(payer, address(this), nftId);

            receiverNftBalance.add(nftId);
        }
    }

    function withdrawNfts(
        address payer,
        address receiver,
        uint256[] calldata nftIds
    ) external override onlyOwner withSupportedNft {
        EnumerableSet.UintSet storage payerNftBalance = _usersInfo[payer]
            .balances[IGovPool.VoteType.PersonalVote]
            .nfts;

        IERC721 nft = IERC721(_nftInfo.nftAddress);

        for (uint256 i; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];

            require(
                payerNftBalance.contains(nftId) && _nftLockedNums[nftId] == 0,
                "GovUK: NFT is not owned or locked"
            );

            payerNftBalance.remove(nftId);

            nft.safeTransferFrom(address(this), receiver, nftId);
        }
    }

    function delegateNfts(
        address delegator,
        address delegatee,
        uint256[] calldata nftIds
    ) external override onlyOwner withSupportedNft {
        UserInfo storage delegatorInfo = _usersInfo[delegator];
        UserInfo storage delegateeInfo = _usersInfo[delegatee];

        EnumerableSet.UintSet storage delegatorNftBalance = delegatorInfo
            .balances[IGovPool.VoteType.PersonalVote]
            .nfts;
        EnumerableSet.UintSet storage delegatedNfts = delegatorInfo
            .delegatedBalances[delegatee]
            .nfts;
        EnumerableSet.UintSet storage allDelegatedNfts = delegatorInfo.allDelegatedBalance.nfts;

        EnumerableSet.UintSet storage delegateeNftBalance = delegateeInfo
            .balances[IGovPool.VoteType.MicropoolVote]
            .nfts;

        IERC721Power nft = IERC721Power(_nftInfo.nftAddress);
        bool isSupportPower = _nftInfo.isSupportPower;
        uint256 nftPower;

        for (uint256 i; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];

            require(
                delegatorNftBalance.contains(nftId) && _nftLockedNums[nftId] == 0,
                "GovUK: NFT is not owned or locked"
            );

            delegatorNftBalance.remove(nftId);

            delegatedNfts.add(nftId);
            allDelegatedNfts.add(nftId);

            delegateeNftBalance.add(nftId);

            if (isSupportPower) {
                _nftInfo.nftMinPower[nftId] = nft.getNftMinPower(nftId);
                nftPower += _nftInfo.nftMinPower[nftId];
            }
        }

        delegatorInfo.delegatees.add(delegatee);

        if (isSupportPower) {
            delegatorInfo.delegatedNftPowers[delegatee] += nftPower;
            delegateeInfo.nftsPowers[IGovPool.VoteType.MicropoolVote] += nftPower;
        }
    }

    function delegateNftsTreasury(
        address delegatee,
        uint256[] calldata nftIds
    ) external override onlyOwner withSupportedNft {
        UserInfo storage delegateeInfo = _usersInfo[delegatee];
        EnumerableSet.UintSet storage delegateeNftBalance = delegateeInfo
            .balances[IGovPool.VoteType.TreasuryVote]
            .nfts;

        IERC721Power nft = IERC721Power(_nftInfo.nftAddress);
        bool isSupportPower = _nftInfo.isSupportPower;
        uint256 nftPower;

        for (uint256 i; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];

            delegateeNftBalance.add(nftId);

            if (isSupportPower) {
                _nftInfo.nftMinPower[nftId] = nft.getNftMinPower(nftId);
                nftPower += _nftInfo.nftMinPower[nftId];
            }
        }

        if (isSupportPower) {
            delegateeInfo.nftsPowers[IGovPool.VoteType.TreasuryVote] += nftPower;
        }
    }

    function undelegateNfts(
        address delegator,
        address delegatee,
        uint256[] calldata nftIds
    ) external override onlyOwner withSupportedNft {
        UserInfo storage delegatorInfo = _usersInfo[delegator];
        UserInfo storage delegateeInfo = _usersInfo[delegatee];

        EnumerableSet.UintSet storage delegatorNftBalance = delegatorInfo
            .balances[IGovPool.VoteType.PersonalVote]
            .nfts;
        EnumerableSet.UintSet storage delegatedNfts = delegatorInfo
            .delegatedBalances[delegatee]
            .nfts;
        EnumerableSet.UintSet storage allDelegatedNfts = delegatorInfo.allDelegatedBalance.nfts;

        EnumerableSet.UintSet storage delegateeNftBalance = delegateeInfo
            .balances[IGovPool.VoteType.MicropoolVote]
            .nfts;

        bool isSupportPower = _nftInfo.isSupportPower;
        uint256 nftPower;

        for (uint256 i; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];

            require(delegatedNfts.contains(nftId), "GovUK: NFT is not delegated");

            delegateeNftBalance.remove(nftId);

            delegatedNfts.remove(nftId);
            allDelegatedNfts.remove(nftId);

            delegatorNftBalance.add(nftId);

            if (isSupportPower) {
                nftPower += _nftInfo.nftMinPower[nftId];
                delete _nftInfo.nftMinPower[nftId];
            }
        }

        if (isSupportPower) {
            delegatorInfo.delegatedNftPowers[delegatee] -= nftPower;
            delegateeInfo.nftsPowers[IGovPool.VoteType.MicropoolVote] -= nftPower;
        }

        _cleanDelegatee(delegatorInfo, delegatee);
    }

    function undelegateNftsTreasury(
        address delegatee,
        uint256[] calldata nftIds
    ) external override onlyOwner withSupportedNft {
        UserInfo storage delegateeInfo = _usersInfo[delegatee];
        EnumerableSet.UintSet storage delegateeNftBalance = delegateeInfo
            .balances[IGovPool.VoteType.TreasuryVote]
            .nfts;

        IERC721 nft = IERC721(_nftInfo.nftAddress);
        bool isSupportPower = _nftInfo.isSupportPower;
        uint256 nftPower;

        for (uint256 i; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];

            require(delegateeNftBalance.remove(nftId), "GovUK: NFT is not owned");

            nft.safeTransferFrom(address(this), msg.sender, nftId);

            if (isSupportPower) {
                nftPower += _nftInfo.nftMinPower[nftId];
                delete _nftInfo.nftMinPower[nftId];
            }
        }

        if (isSupportPower) {
            delegateeInfo.nftsPowers[IGovPool.VoteType.TreasuryVote] -= nftPower;
        }
    }

    function updateMaxTokenLockedAmount(
        uint256[] calldata lockedProposals,
        address voter
    ) external override onlyOwner {
        UserInfo storage voterInfo = _usersInfo[voter];

        uint256 lockedAmount = voterInfo.maxTokensLocked;
        uint256 newLockedAmount;

        for (uint256 i; i < lockedProposals.length; i++) {
            newLockedAmount = newLockedAmount.max(voterInfo.lockedInProposals[lockedProposals[i]]);

            if (newLockedAmount == lockedAmount) {
                return;
            }
        }

        voterInfo.maxTokensLocked = newLockedAmount;
    }

    function lockTokens(
        uint256 proposalId,
        address voter,
        uint256 amount
    ) external override onlyOwner {
        UserInfo storage voterInfo = _usersInfo[voter];

        voterInfo.lockedInProposals[proposalId] = amount;
        voterInfo.maxTokensLocked = voterInfo.maxTokensLocked.max(
            voterInfo.lockedInProposals[proposalId]
        );
    }

    function unlockTokens(uint256 proposalId, address voter) external override onlyOwner {
        delete _usersInfo[voter].lockedInProposals[proposalId];
    }

    function lockNfts(
        address voter,
        IGovPool.VoteType voteType,
        uint256[] calldata nftIds
    ) external override onlyOwner {
        UserInfo storage voterInfo = _usersInfo[voter];
        EnumerableSet.UintSet storage voteNftBalance = voterInfo
            .balances[IGovPool.VoteType.PersonalVote]
            .nfts;

        for (uint256 i; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];

            bool hasNft = voteNftBalance.contains(nftId);

            if (voteType == IGovPool.VoteType.DelegatedVote) {
                hasNft = hasNft || voterInfo.allDelegatedBalance.nfts.contains(nftId);
            }

            require(hasNft, "GovUK: NFT is not owned");

            _nftLockedNums[nftId]++;
        }
    }

    function unlockNfts(uint256[] calldata nftIds) external override onlyOwner {
        for (uint256 i; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];

            require(_nftLockedNums[nftId] > 0, "GovUK: NFT is not locked");

            _nftLockedNums[nftId]--;
        }
    }

    function updateNftPowers(uint256[] calldata nftIds) external override onlyOwner {
        if (!_nftInfo.isSupportPower) {
            return;
        }

        IERC721Power(_nftInfo.nftAddress).recalculateNftPowers(nftIds);
    }

    function setERC20Address(address _tokenAddress) external override onlyOwner {
        _setERC20Address(_tokenAddress);
    }

    function setERC721Address(
        address _nftAddress,
        uint256 individualPower,
        uint256 nftsTotalSupply
    ) external override onlyOwner {
        _setERC721Address(_nftAddress, individualPower, nftsTotalSupply);
    }

    receive() external payable {}

    function nftAddress() external view override returns (address) {
        return _nftInfo.nftAddress;
    }

    function getNftInfo()
        external
        view
        override
        returns (bool isSupportPower, uint256 individualPower, uint256 totalSupply)
    {
        return (_nftInfo.isSupportPower, _nftInfo.individualPower, _nftInfo.totalSupply);
    }

    function maxLockedAmount(address voter) external view override returns (uint256) {
        return _usersInfo[voter].maxTokensLocked;
    }

    function tokenBalance(
        address voter,
        IGovPool.VoteType voteType
    ) public view override returns (uint256 totalBalance, uint256 ownedBalance) {
        if (tokenAddress == address(0)) {
            return (0, 0);
        }

        totalBalance = _getBalanceInfoStorage(voter, voteType).tokens;

        if (
            voteType != IGovPool.VoteType.PersonalVote &&
            voteType != IGovPool.VoteType.DelegatedVote
        ) {
            return (totalBalance, 0);
        }

        if (voteType == IGovPool.VoteType.DelegatedVote) {
            totalBalance += _usersInfo[voter].allDelegatedBalance.tokens;
        }

        ownedBalance = ERC20(tokenAddress).balanceOf(voter).to18(tokenAddress);

        if (_isWrapped()) {
            ownedBalance += address(voter).balance;
        }

        totalBalance += ownedBalance;
    }

    function nftBalance(
        address voter,
        IGovPool.VoteType voteType
    ) external view override returns (uint256 totalBalance, uint256 ownedBalance) {
        address nftAddress_ = _nftInfo.nftAddress;

        if (nftAddress_ == address(0)) {
            return (0, 0);
        }

        totalBalance = _getBalanceInfoStorage(voter, voteType).nfts.length();

        if (
            voteType != IGovPool.VoteType.PersonalVote &&
            voteType != IGovPool.VoteType.DelegatedVote
        ) {
            return (totalBalance, 0);
        }

        if (voteType == IGovPool.VoteType.DelegatedVote) {
            totalBalance += _usersInfo[voter].allDelegatedBalance.nfts.length();
        }

        ownedBalance = IERC721Upgradeable(nftAddress_).balanceOf(voter);
        totalBalance += ownedBalance;
    }

    function nftExactBalance(
        address voter,
        IGovPool.VoteType voteType
    ) public view override returns (uint256[] memory nfts, uint256 ownedLength) {
        address nftAddress_ = _nftInfo.nftAddress;

        if (nftAddress_ == address(0)) {
            return (nfts, 0);
        }

        Vector.UintVector memory nftsVector = Vector.newUint(
            _getBalanceInfoStorage(voter, voteType).nfts.values()
        );

        if (
            voteType != IGovPool.VoteType.PersonalVote &&
            voteType != IGovPool.VoteType.DelegatedVote
        ) {
            return (nftsVector.toArray(), 0);
        }

        if (voteType == IGovPool.VoteType.DelegatedVote) {
            nftsVector.push(_usersInfo[voter].allDelegatedBalance.nfts.values());
        }

        ownedLength = IERC721Upgradeable(nftAddress_).balanceOf(voter);

        if (_nftInfo.totalSupply != 0) {
            nftsVector.push(new uint256[](ownedLength));

            return (nftsVector.toArray(), ownedLength);
        }

        IERC721Power nftContract = IERC721Power(nftAddress_);

        for (uint256 i; i < ownedLength; i++) {
            nftsVector.push(nftContract.tokenOfOwnerByIndex(voter, i));
        }

        return (nftsVector.toArray(), ownedLength);
    }

    function getTotalNftsPower(
        uint256[] memory nftIds,
        IGovPool.VoteType voteType,
        address voter,
        bool perNftPowerArray
    ) public view override returns (uint256 nftPower, uint256[] memory perNftPower) {
        return _usersInfo.getTotalNftsPower(_nftInfo, nftIds, voteType, voter, perNftPowerArray);
    }

    function getTotalPower() external view override returns (uint256 power) {
        address token = tokenAddress;

        if (token != address(0)) {
            if (_isWrapped()) {
                power = INetworkProperties(networkPropertiesAddress).getNativeSupply();
            } else {
                power = IERC20(token).totalSupply().to18(token);
            }
        }

        token = _nftInfo.nftAddress;

        if (token != address(0)) {
            if (!_nftInfo.isSupportPower) {
                power +=
                    _nftInfo.individualPower *
                    (
                        _nftInfo.totalSupply == 0
                            ? IERC721Power(token).totalSupply()
                            : _nftInfo.totalSupply
                    );
            } else {
                power += IERC721Power(token).totalPower();
            }
        }
    }

    function canCreate(
        address voter,
        IGovPool.VoteType voteType,
        uint256 requiredVotes
    ) external view override returns (bool) {
        (uint256 tokens, uint256 ownedBalance) = tokenBalance(voter, voteType);
        (uint256 tokensMicropool, ) = tokenBalance(voter, IGovPool.VoteType.MicropoolVote);
        (uint256 tokensTreasury, ) = tokenBalance(voter, IGovPool.VoteType.TreasuryVote);

        tokens = tokens + tokensMicropool + tokensTreasury - ownedBalance;

        if (tokens >= requiredVotes) {
            return true;
        }

        (uint256[] memory nftIds, uint256 owned) = nftExactBalance(voter, voteType);

        nftIds.crop(nftIds.length - owned);

        (uint256 personalNftPower, ) = getTotalNftsPower(
            nftIds,
            IGovPool.VoteType.PersonalVote,
            address(0),
            false
        );
        (uint256 micropoolNftPower, ) = getTotalNftsPower(
            new uint256[](0),
            IGovPool.VoteType.MicropoolVote,
            voter,
            false
        );
        (uint256 treasuryNftPower, ) = getTotalNftsPower(
            new uint256[](0),
            IGovPool.VoteType.TreasuryVote,
            voter,
            false
        );

        return tokens + personalNftPower + micropoolNftPower + treasuryNftPower >= requiredVotes;
    }

    function votingPower(
        address[] calldata users,
        IGovPool.VoteType[] calldata voteTypes,
        bool perNftPowerArray
    ) external view override returns (VotingPowerView[] memory votingPowers) {
        return _usersInfo.votingPower(_nftInfo, tokenAddress, users, voteTypes, perNftPowerArray);
    }

    function transformedVotingPower(
        address voter,
        uint256 amount,
        uint256[] calldata nftIds
    ) external view override returns (uint256 personalPower, uint256 fullPower) {
        return _usersInfo.transformedVotingPower(_nftInfo, tokenAddress, voter, amount, nftIds);
    }

    function delegations(
        address user,
        bool perNftPowerArray
    ) external view override returns (uint256 power, DelegationInfoView[] memory delegationsInfo) {
        return _usersInfo.delegations(_nftInfo, user, perNftPowerArray);
    }

    function getWithdrawableAssets(
        address voter,
        uint256[] calldata lockedProposals,
        uint256[] calldata unlockedNfts
    )
        external
        view
        override
        returns (uint256 withdrawableTokens, uint256[] memory withdrawableNfts)
    {
        return
            lockedProposals.getWithdrawableAssets(unlockedNfts, _usersInfo[voter], _nftLockedNums);
    }

    function getDelegatedAssetsPower(
        address delegator,
        address delegatee
    ) external view override returns (uint256 delegatedPower) {
        UserInfo storage delegatorInfo = _usersInfo[delegator];
        BalanceInfo storage delegatedBalance = delegatorInfo.delegatedBalances[delegatee];

        return
            delegatedBalance.tokens +
            (
                _nftInfo.isSupportPower
                    ? delegatorInfo.delegatedNftPowers[delegatee]
                    : delegatedBalance.nfts.length() * _nftInfo.individualPower
            );
    }

    function getAmountWithNativeDecimals(
        uint256 value,
        uint256 amount
    ) public view returns (uint256 nativeAmount) {
        require(
            value == 0 || _isWrapped(),
            "GovUK: should not send ether if Gov token is not native"
        );

        nativeAmount = amount.from18Safe(tokenAddress);
        require(nativeAmount >= value, "GovUK: ether value is greater than amount");

        nativeAmount -= value;
    }

    function _sendNativeOrToken(address receiver, uint256 amount) internal {
        address token = tokenAddress;
        amount = amount.from18Safe(token);

        if (_isWrapped()) {
            _handleNative(amount, false);

            (bool ok, ) = payable(receiver).call{value: amount}("");
            require(ok, "GovUK: can't send ether");
        } else {
            IERC20(token).safeTransfer(receiver, amount);
        }
    }

    function _cleanDelegatee(UserInfo storage delegatorInfo, address delegatee) internal {
        BalanceInfo storage delegatedBalance = delegatorInfo.delegatedBalances[delegatee];

        if (delegatedBalance.tokens == 0 && delegatedBalance.nfts.length() == 0) {
            delegatorInfo.delegatees.remove(delegatee);
        }
    }

    function _setERC20Address(address _tokenAddress) internal {
        require(tokenAddress == address(0), "GovUK: current token address isn't zero");
        require(_tokenAddress != address(0), "GovUK: new token address is zero");

        tokenAddress = _tokenAddress;

        emit SetERC20(_tokenAddress);
    }

    function _setERC721Address(
        address _nftAddress,
        uint256 individualPower,
        uint256 nftsTotalSupply
    ) internal {
        require(_nftInfo.nftAddress == address(0), "GovUK: current token address isn't zero");
        require(_nftAddress != address(0), "GovUK: new token address is zero");

        if (IERC165(_nftAddress).supportsInterface(type(IERC721Power).interfaceId)) {
            _nftInfo.isSupportPower = true;
        } else {
            require(individualPower > 0, "GovUK: the individual power is zero");

            _nftInfo.individualPower = individualPower;

            if (
                !IERC165(_nftAddress).supportsInterface(
                    type(IERC721EnumerableUpgradeable).interfaceId
                )
            ) {
                require(uint128(nftsTotalSupply) > 0, "GovUK: total supply is zero");

                _nftInfo.totalSupply = uint128(nftsTotalSupply);
            }
        }

        _nftInfo.nftAddress = _nftAddress;

        emit SetERC721(_nftAddress);
    }

    function _getBalanceInfoStorage(
        address voter,
        IGovPool.VoteType voteType
    ) internal view returns (BalanceInfo storage) {
        return
            voteType == IGovPool.VoteType.DelegatedVote
                ? _usersInfo[voter].balances[IGovPool.VoteType.PersonalVote]
                : _usersInfo[voter].balances[voteType];
    }

    function _withSupportedToken() internal view {
        require(tokenAddress != address(0), "GovUK: token is not supported");
    }

    function _withSupportedNft() internal view {
        require(_nftInfo.nftAddress != address(0), "GovUK: nft is not supported");
    }

    function _handleNative(uint256 value, bool wrapping) internal {
        if (value == 0) {
            return;
        }

        if (wrapping) {
            IWETH(wethAddress).deposit{value: value}();
        } else {
            IWETH(wethAddress).transfer(networkPropertiesAddress, value);
            INetworkProperties(networkPropertiesAddress).unwrapWeth(value);
        }
    }

    function _isWrapped() internal view returns (bool) {
        address _wethAddress = wethAddress;

        return _wethAddress != address(0) && wethAddress == tokenAddress;
    }
}
