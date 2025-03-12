// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@solarity/solidity-lib/libs/utils/DecimalsConverter.sol";
import "@solarity/solidity-lib/libs/arrays/SetHelper.sol";

import "../../../gov/proposals/TokenSaleProposal.sol";

import "../../../libs/utils/TokenBalance.sol";
import "./TokenSaleProposalBuy.sol";

library TokenSaleProposalWhitelist {
    using TokenSaleProposalBuy for ITokenSaleProposal.Tier;
    using TokenBalance for address;
    using DecimalsConverter for *;
    using SetHelper for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;
    using EnumerableSet for *;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    function lockParticipationTokens(
        ITokenSaleProposal.Tier storage tier,
        address tokenToLock,
        uint256 amountToLock
    ) external {
        ITokenSaleProposal.ParticipationInfo storage participationInfo = tier.participationInfo;
        EnumerableMap.AddressToUintMap storage lockedTokens = tier
            .users[msg.sender]
            .purchaseInfo
            .lockedTokens;

        require(amountToLock > 0, "TSP: zero amount to lock");

        (, uint256 lockedAmount) = lockedTokens.tryGet(tokenToLock);
        (, uint256 requiredAmount) = participationInfo.requiredTokenLock.tryGet(tokenToLock);

        uint256 newLockedAmount = lockedAmount + amountToLock;

        require(newLockedAmount <= requiredAmount, "TSP: token overlock");

        lockedTokens.set(tokenToLock, newLockedAmount);

        if (tokenToLock != ETHEREUM_ADDRESS) {
            require(msg.value == 0, "TSP: wrong native lock amount");

            IERC20(tokenToLock).safeTransferFrom(
                msg.sender,
                address(this),
                amountToLock.from18Safe(tokenToLock)
            );
        } else {
            require(msg.value == amountToLock, "TSP: wrong lock amount");
        }
    }

    function lockParticipationNft(
        ITokenSaleProposal.Tier storage tier,
        address nftToLock,
        uint256[] calldata nftIdsToLock
    ) external {
        ITokenSaleProposal.PurchaseInfo storage purchaseInfo = tier.users[msg.sender].purchaseInfo;
        EnumerableSet.UintSet storage lockedNfts = purchaseInfo.lockedNfts[nftToLock];

        require(nftIdsToLock.length > 0, "TSP: zero nft ids to lock");

        purchaseInfo.lockedNftAddresses.add(nftToLock);

        for (uint256 i = 0; i < nftIdsToLock.length; i++) {
            require(lockedNfts.add(nftIdsToLock[i]), "TSP: lock nfts are duplicated");
        }

        (, uint256 requiredAmount) = tier.participationInfo.requiredNftLock.tryGet(nftToLock);

        require(lockedNfts.length() <= requiredAmount, "TSP: nft overlock");

        for (uint256 i = 0; i < nftIdsToLock.length; i++) {
            IERC721(nftToLock).safeTransferFrom(msg.sender, address(this), nftIdsToLock[i]);
        }
    }

    function unlockParticipationTokens(
        ITokenSaleProposal.Tier storage tier,
        address tokenToUnlock,
        uint256 amountToUnlock
    ) external {
        EnumerableMap.AddressToUintMap storage lockedTokens = tier
            .users[msg.sender]
            .purchaseInfo
            .lockedTokens;
        EnumerableMap.AddressToUintMap storage requiredTokenLock = tier
            .participationInfo
            .requiredTokenLock;

        (, uint256 lockedAmount) = lockedTokens.tryGet(tokenToUnlock);
        (, uint256 requiredAmount) = requiredTokenLock.tryGet(tokenToUnlock);
        uint256 overlock = lockedAmount < requiredAmount ? 0 : lockedAmount - requiredAmount;

        require(
            block.timestamp >= tier.tierInitParams.saleEndTime ||
                (!tier._checkUserLockedTokens(msg.sender) &&
                    _getBlockNumber() != tier.tierAdditionalInfo.lastModified) ||
                overlock >= amountToUnlock,
            "TSP: unlock unavailable"
        );

        require(amountToUnlock > 0, "TSP: zero amount to unlock");

        require(amountToUnlock <= lockedAmount, "TSP: unlock exceeds lock");

        if (amountToUnlock == lockedAmount) {
            lockedTokens.remove(tokenToUnlock);
        } else {
            lockedTokens.set(tokenToUnlock, lockedAmount - amountToUnlock);
        }

        tokenToUnlock.sendFunds(msg.sender, amountToUnlock);
    }

    function unlockParticipationNft(
        ITokenSaleProposal.Tier storage tier,
        address nftToUnlock,
        uint256[] calldata nftIdsToUnlock
    ) external {
        ITokenSaleProposal.PurchaseInfo storage purchaseInfo = tier.users[msg.sender].purchaseInfo;
        EnumerableSet.UintSet storage lockedNfts = purchaseInfo.lockedNfts[nftToUnlock];
        EnumerableMap.AddressToUintMap storage requiredNftLock = tier
            .participationInfo
            .requiredNftLock;

        (, uint256 requiredAmount) = requiredNftLock.tryGet(nftToUnlock);
        uint256 lockedAmount = lockedNfts.length();
        uint256 overlock = lockedAmount < requiredAmount ? 0 : lockedAmount - requiredAmount;

        require(
            block.timestamp >= tier.tierInitParams.saleEndTime ||
                (!tier._checkUserLockedNfts(msg.sender) &&
                    _getBlockNumber() != tier.tierAdditionalInfo.lastModified) ||
                overlock >= nftIdsToUnlock.length,
            "TSP: unlock unavailable"
        );

        require(nftIdsToUnlock.length > 0, "TSP: zero nft ids to unlock");

        for (uint256 i = 0; i < nftIdsToUnlock.length; i++) {
            require(lockedNfts.remove(nftIdsToUnlock[i]), "TSP: nft is not locked");
        }

        if (lockedNfts.length() == 0) {
            purchaseInfo.lockedNftAddresses.remove(nftToUnlock);
        }

        for (uint256 i = 0; i < nftIdsToUnlock.length; i++) {
            IERC721(nftToUnlock).safeTransferFrom(address(this), msg.sender, nftIdsToUnlock[i]);
        }
    }

    function addToWhitelist(
        ITokenSaleProposal.Tier storage tier,
        ITokenSaleProposal.WhitelistingRequest calldata request
    ) external {
        require(tier.participationInfo.isWhitelisted, "TSP: tier is not whitelisted");

        tier.tierInfo.uri = request.uri;

        for (uint256 i = 0; i < request.users.length; i++) {
            TokenSaleProposal(address(this)).mint(request.users[i], request.tierId);
        }
    }

    function _getBlockNumber() internal view returns (uint256 block_) {
        return block.number;
    }
}
