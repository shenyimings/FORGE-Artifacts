// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "@solarity/solidity-lib/libs/utils/TypeCaster.sol";
import "@solarity/solidity-lib/libs/utils/DecimalsConverter.sol";

import "../../../interfaces/gov/proposals/ITokenSaleProposal.sol";
import "../../../interfaces/gov/IGovPool.sol";
import "../../../interfaces/gov/user-keeper/IGovUserKeeper.sol";

import "../../../core/CoreProperties.sol";
import "../../../gov/proposals/TokenSaleProposal.sol";

import "../../../libs/math/MathHelper.sol";
import "../../../libs/utils/TypeHelper.sol";

library TokenSaleProposalBuy {
    using MathHelper for uint256;
    using DecimalsConverter for *;
    using TypeCaster for *;
    using TypeHelper for *;
    using SafeERC20 for IERC20;
    using EnumerableSet for *;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using MerkleProof for *;

    function buy(
        ITokenSaleProposal.Tier storage tier,
        uint256 tierId,
        address tokenToBuyWith,
        uint256 amount,
        bytes32[] calldata proof
    ) external returns (uint256 saleTokenAmount) {
        ITokenSaleProposal.UserInfo storage userInfo = tier.users[msg.sender];
        ITokenSaleProposal.PurchaseInfo storage purchaseInfo = userInfo.purchaseInfo;
        ITokenSaleProposal.TierInitParams storage tierInitParams = tier.tierInitParams;

        require(
            (tokenToBuyWith != ETHEREUM_ADDRESS && msg.value == 0) || amount == msg.value,
            "TSP: wrong native amount"
        );

        saleTokenAmount = getSaleTokenAmount(
            tier,
            msg.sender,
            tierId,
            tokenToBuyWith,
            amount,
            proof
        );

        uint256 vestingCurrentAmount = saleTokenAmount.percentage(
            tierInitParams.vestingSettings.vestingPercentage
        );
        uint256 claimCurrentAmount = saleTokenAmount - vestingCurrentAmount;

        tier.tierInfo.totalSold += saleTokenAmount;

        (, uint256 previousSpentAmount) = purchaseInfo.spentAmounts.tryGet(tokenToBuyWith);
        purchaseInfo.spentAmounts.set(tokenToBuyWith, previousSpentAmount + amount);
        purchaseInfo.claimTotalAmount += claimCurrentAmount;

        userInfo.vestingUserInfo.vestingTotalAmount += vestingCurrentAmount;

        _purchaseWithCommission(tokenToBuyWith, amount);
    }

    function _purchaseWithCommission(address token, uint256 amount) internal {
        TokenSaleProposal tokenSaleProposal = TokenSaleProposal(address(this));
        address govAddress = tokenSaleProposal.govAddress();
        address dexeGovAddress = tokenSaleProposal.dexeGovAddress();

        if (govAddress != dexeGovAddress) {
            CoreProperties coreProperties = CoreProperties(tokenSaleProposal.coreProperties());

            uint256 commission = amount.percentage(
                coreProperties.getTokenSaleProposalCommissionPercentage()
            );

            _sendFunds(token, dexeGovAddress, commission);

            amount -= commission;
        }

        _sendFunds(token, govAddress, amount);
    }

    function _sendFunds(address token, address to, uint256 amount) internal {
        if (token == ETHEREUM_ADDRESS) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "TSP: failed to transfer ether");
        } else {
            IERC20(token).safeTransferFrom(msg.sender, to, amount.from18Safe(token));
        }
    }

    function getSaleTokenAmount(
        ITokenSaleProposal.Tier storage tier,
        address user,
        uint256 tierId,
        address tokenToBuyWith,
        uint256 amount,
        bytes32[] calldata proof
    ) public view returns (uint256) {
        ITokenSaleProposal.TierInitParams memory tierInitParams = tier.tierInitParams;
        ITokenSaleProposal.UserInfo storage userInfo = tier.users[msg.sender];

        require(amount > 0, "TSP: zero amount");
        require(canParticipate(tier, tierId, user, proof), "TSP: cannot participate");
        require(
            tierInitParams.saleStartTime <= block.timestamp &&
                block.timestamp <= tierInitParams.saleEndTime,
            "TSP: cannot buy now"
        );

        uint256 exchangeRate = tier.rates[tokenToBuyWith];

        require(exchangeRate != 0, "TSP: incorrect token");

        uint256 saleTokenAmount = amount.ratio(PRECISION, exchangeRate);
        uint256 userBoughtAmount = saleTokenAmount +
            userInfo.purchaseInfo.claimTotalAmount +
            userInfo.vestingUserInfo.vestingTotalAmount;

        require(
            tierInitParams.maxAllocationPerUser == 0 ||
                (tierInitParams.minAllocationPerUser <= userBoughtAmount &&
                    userBoughtAmount <= tierInitParams.maxAllocationPerUser),
            "TSP: wrong allocation"
        );
        require(
            tier.tierInfo.totalSold + saleTokenAmount <= tierInitParams.totalTokenProvided,
            "TSP: insufficient sale token amount"
        );

        return saleTokenAmount;
    }

    function canParticipate(
        ITokenSaleProposal.Tier storage tier,
        uint256 tierId,
        address user,
        bytes32[] calldata proof
    ) public view returns (bool) {
        ITokenSaleProposal.ParticipationInfo storage participationInfo = tier.participationInfo;
        TokenSaleProposal tokenSaleProposal = TokenSaleProposal(address(this));

        bool _canParticipate = true;

        if (participationInfo.requiredDaoVotes > 0) {
            (, address govUserKeeper, , , ) = IGovPool(tokenSaleProposal.govAddress())
                .getHelperContracts();

            _canParticipate =
                IGovUserKeeper(govUserKeeper)
                .votingPower(
                    user.asSingletonArray(),
                    IGovPool.VoteType.DelegatedVote.asSingletonArray(),
                    false
                )[0].rawPower >
                participationInfo.requiredDaoVotes;
        }

        bool isMerkleRootPresent = tier.tierAdditionalInfo.merkleRoot != bytes32(0);

        if (_canParticipate && (participationInfo.isWhitelisted || isMerkleRootPresent)) {
            bool turnedOnAndWhitelisted = participationInfo.isWhitelisted &&
                tokenSaleProposal.balanceOf(user, tierId) > 0;

            _canParticipate = turnedOnAndWhitelisted || _checkMerkleProofs(tier, proof, user);
        }

        if (_canParticipate && participationInfo.isBABTed) {
            _canParticipate = tokenSaleProposal.babt().balanceOf(user) > 0;
        }

        if (_canParticipate && participationInfo.requiredTokenLock.length() > 0) {
            _canParticipate = _checkUserLockedTokens(tier, user);
        }

        if (_canParticipate && participationInfo.requiredNftLock.length() > 0) {
            _canParticipate = _checkUserLockedNfts(tier, user);
        }

        return _canParticipate;
    }

    function getPurchaseView(
        ITokenSaleProposal.Tier storage tier,
        address user
    ) external view returns (ITokenSaleProposal.PurchaseView memory purchaseView) {
        ITokenSaleProposal.UserInfo storage userInfo = tier.users[user];
        ITokenSaleProposal.PurchaseInfo storage purchaseInfo = userInfo.purchaseInfo;
        ITokenSaleProposal.TierInitParams memory tierInitParams = tier.tierInitParams;

        purchaseView.isClaimed = purchaseInfo.isClaimed;
        purchaseView.claimUnlockTime =
            tierInitParams.saleEndTime +
            tierInitParams.claimLockDuration;
        purchaseView.canClaim = purchaseView.claimUnlockTime <= block.timestamp;
        purchaseView.claimTotalAmount = purchaseInfo.claimTotalAmount;
        purchaseView.boughtTotalAmount =
            purchaseView.claimTotalAmount +
            userInfo.vestingUserInfo.vestingTotalAmount;

        uint256 lockedTokenLength = purchaseInfo.lockedTokens.length();

        purchaseView.lockedTokenAddresses = new address[](lockedTokenLength);
        purchaseView.lockedTokenAmounts = new uint256[](lockedTokenLength);

        for (uint256 i = 0; i < lockedTokenLength; i++) {
            (
                purchaseView.lockedTokenAddresses[i],
                purchaseView.lockedTokenAmounts[i]
            ) = purchaseInfo.lockedTokens.at(i);
        }

        uint256 lockedNftLength = purchaseInfo.lockedNftAddresses.length();

        purchaseView.lockedNftAddresses = new address[](lockedNftLength);
        purchaseView.lockedNftIds = new uint256[][](lockedNftLength);

        for (uint256 i = 0; i < lockedNftLength; i++) {
            address lockedNftAddress = purchaseInfo.lockedNftAddresses.at(i);

            purchaseView.lockedNftAddresses[i] = lockedNftAddress;
            purchaseView.lockedNftIds[i] = purchaseInfo.lockedNfts[lockedNftAddress].values();
        }

        uint256 purchaseTokenLength = purchaseInfo.spentAmounts.length();

        purchaseView.purchaseTokenAddresses = new address[](purchaseTokenLength);
        purchaseView.purchaseTokenAmounts = new uint256[](purchaseTokenLength);

        for (uint256 i = 0; i < purchaseTokenLength; i++) {
            (
                purchaseView.purchaseTokenAddresses[i],
                purchaseView.purchaseTokenAmounts[i]
            ) = purchaseInfo.spentAmounts.at(i);
        }
    }

    function _checkUserLockedTokens(
        ITokenSaleProposal.Tier storage tier,
        address user
    ) internal view returns (bool) {
        EnumerableMap.AddressToUintMap storage requiredTokenLock = tier
            .participationInfo
            .requiredTokenLock;
        EnumerableMap.AddressToUintMap storage lockedTokens = tier
            .users[user]
            .purchaseInfo
            .lockedTokens;

        uint256 length = requiredTokenLock.length();

        for (uint256 i = 0; i < length; i++) {
            (address requiredToken, uint256 requiredAmount) = requiredTokenLock.at(i);

            (, uint256 lockedAmount) = lockedTokens.tryGet(requiredToken);

            if (lockedAmount < requiredAmount) {
                return false;
            }
        }

        return true;
    }

    function _checkUserLockedNfts(
        ITokenSaleProposal.Tier storage tier,
        address user
    ) internal view returns (bool) {
        EnumerableMap.AddressToUintMap storage requiredNftLock = tier
            .participationInfo
            .requiredNftLock;
        mapping(address => EnumerableSet.UintSet) storage lockedNfts = tier
            .users[user]
            .purchaseInfo
            .lockedNfts;

        uint256 length = requiredNftLock.length();

        for (uint256 i = 0; i < length; i++) {
            (address requiredNft, uint256 requiredAmount) = requiredNftLock.at(i);

            if (lockedNfts[requiredNft].length() < requiredAmount) {
                return false;
            }
        }

        return true;
    }

    function _checkMerkleProofs(
        ITokenSaleProposal.Tier storage tier,
        bytes32[] calldata proof,
        address user
    ) internal view returns (bool) {
        bytes32 root = tier.tierAdditionalInfo.merkleRoot;

        if (root == bytes32(0)) {
            return false;
        }

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(user))));

        return proof.verifyCalldata(root, leaf);
    }
}
