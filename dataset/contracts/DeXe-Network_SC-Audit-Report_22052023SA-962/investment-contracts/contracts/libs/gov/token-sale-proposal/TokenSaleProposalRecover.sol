// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../interfaces/gov/proposals/ITokenSaleProposal.sol";

import "../../../libs/utils/TokenBalance.sol";

library TokenSaleProposalRecover {
    using TokenBalance for IERC20;

    function recover(ITokenSaleProposal.Tier storage tier) external {
        uint256 recoveringAmount = getRecoverAmount(tier);
        require(recoveringAmount > 0, "TSP: zero recovery");

        tier.tierInfo.totalSold += recoveringAmount;

        IERC20(tier.tierInitParams.saleTokenAddress).sendFunds(msg.sender, recoveringAmount);
    }

    function getRecoverAmount(ITokenSaleProposal.Tier storage tier) public view returns (uint256) {
        ITokenSaleProposal.TierInitParams memory tierInitParams = tier.tierInitParams;
        ITokenSaleProposal.TierInfo memory tierInfo = tier.tierInfo;

        if (!tierInfo.isOff && block.timestamp <= tierInitParams.saleEndTime) {
            return 0;
        }

        return tierInitParams.totalTokenProvided - tierInfo.totalSold;
    }
}
