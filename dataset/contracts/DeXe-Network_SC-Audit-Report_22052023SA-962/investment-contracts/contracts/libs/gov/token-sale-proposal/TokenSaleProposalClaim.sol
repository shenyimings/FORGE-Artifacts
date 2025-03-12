// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../interfaces/gov/proposals/ITokenSaleProposal.sol";

import "../../../libs/utils/TokenBalance.sol";

library TokenSaleProposalClaim {
    using TokenBalance for IERC20;

    function claim(ITokenSaleProposal.Tier storage tier) external {
        uint256 claimAmount = getClaimAmount(tier, msg.sender);
        require(claimAmount > 0, "TSP: zero withdrawal");

        tier.users[msg.sender].purchaseInfo.isClaimed = true;

        IERC20(tier.tierInitParams.saleTokenAddress).sendFunds(msg.sender, claimAmount);
    }

    function getClaimAmount(
        ITokenSaleProposal.Tier storage tier,
        address user
    ) public view returns (uint256) {
        ITokenSaleProposal.PurchaseInfo storage purchaseInfo = tier.users[user].purchaseInfo;
        ITokenSaleProposal.TierInitParams memory tierInitParams = tier.tierInitParams;

        require(
            block.timestamp >= tierInitParams.saleEndTime + tierInitParams.claimLockDuration,
            "TSP: claim is locked"
        );

        return purchaseInfo.isClaimed ? 0 : purchaseInfo.claimTotalAmount;
    }
}
