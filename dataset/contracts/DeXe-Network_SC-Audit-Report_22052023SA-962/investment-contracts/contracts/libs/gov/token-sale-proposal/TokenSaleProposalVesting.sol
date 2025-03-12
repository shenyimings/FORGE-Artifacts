// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../../interfaces/gov/proposals/ITokenSaleProposal.sol";

import "../../utils/TokenBalance.sol";
import "../../math/MathHelper.sol";

library TokenSaleProposalVesting {
    using Math for uint256;
    using MathHelper for uint256;
    using TokenBalance for IERC20;

    function vestingWithdraw(ITokenSaleProposal.Tier storage tier) external {
        uint256 vestingWithdrawAmount = getVestingWithdrawAmount(tier, msg.sender);
        require(vestingWithdrawAmount > 0, "TSP: zero withdrawal");

        ITokenSaleProposal.VestingUserInfo storage vestingUserInfo = tier
            .users[msg.sender]
            .vestingUserInfo;

        vestingUserInfo.latestVestingWithdraw = uint64(block.timestamp);
        vestingUserInfo.vestingWithdrawnAmount += vestingWithdrawAmount;

        IERC20(tier.tierInitParams.saleTokenAddress).sendFunds(msg.sender, vestingWithdrawAmount);
    }

    function getVestingWithdrawAmount(
        ITokenSaleProposal.Tier storage tier,
        address user
    ) public view returns (uint256) {
        ITokenSaleProposal.VestingUserInfo memory vestingUserInfo = tier
            .users[user]
            .vestingUserInfo;

        return
            _countPrefixVestingAmount(
                block.timestamp,
                vestingUserInfo.vestingTotalAmount,
                tier.tierInfo.vestingTierInfo,
                tier.tierInitParams.vestingSettings
            ) - vestingUserInfo.vestingWithdrawnAmount;
    }

    function getVestingUserView(
        ITokenSaleProposal.Tier storage tier,
        address user
    ) external view returns (ITokenSaleProposal.VestingUserView memory vestingUserView) {
        ITokenSaleProposal.VestingUserInfo memory vestingUserInfo = tier
            .users[user]
            .vestingUserInfo;
        ITokenSaleProposal.VestingTierInfo memory vestingTierInfo = tier.tierInfo.vestingTierInfo;
        ITokenSaleProposal.VestingSettings memory vestingSettings = tier
            .tierInitParams
            .vestingSettings;

        vestingUserView.latestVestingWithdraw = vestingUserInfo.latestVestingWithdraw;
        vestingUserView.vestingTotalAmount = vestingUserInfo.vestingTotalAmount;
        vestingUserView.vestingWithdrawnAmount = vestingUserInfo.vestingWithdrawnAmount;

        if (block.timestamp < vestingTierInfo.vestingStartTime) {
            vestingUserView.nextUnlockTime =
                vestingTierInfo.vestingStartTime +
                vestingSettings.unlockStep;
        } else if (block.timestamp < vestingTierInfo.vestingEndTime) {
            vestingUserView.nextUnlockTime = uint64(block.timestamp) + vestingSettings.unlockStep;
            vestingUserView.nextUnlockTime -=
                (vestingUserView.nextUnlockTime - vestingTierInfo.vestingStartTime) %
                vestingSettings.unlockStep;
            vestingUserView.nextUnlockTime = uint64(
                uint256(vestingUserView.nextUnlockTime).min(vestingTierInfo.vestingEndTime)
            );
        }

        uint256 currentPrefixVestingAmount = _countPrefixVestingAmount(
            block.timestamp,
            vestingUserView.vestingTotalAmount,
            vestingTierInfo,
            vestingSettings
        );

        if (vestingUserView.nextUnlockTime != 0) {
            vestingUserView.nextUnlockAmount =
                _countPrefixVestingAmount(
                    vestingUserView.nextUnlockTime,
                    vestingUserView.vestingTotalAmount,
                    vestingTierInfo,
                    vestingSettings
                ) -
                currentPrefixVestingAmount;
        }

        vestingUserView.amountToWithdraw =
            currentPrefixVestingAmount -
            vestingUserView.vestingWithdrawnAmount;
        vestingUserView.lockedAmount =
            vestingUserView.vestingTotalAmount -
            currentPrefixVestingAmount;
    }

    function _countPrefixVestingAmount(
        uint256 timestamp,
        uint256 vestingTotalAmount,
        ITokenSaleProposal.VestingTierInfo memory vestingTierInfo,
        ITokenSaleProposal.VestingSettings memory vestingSettings
    ) private pure returns (uint256) {
        if (timestamp < vestingTierInfo.vestingStartTime) {
            return 0;
        }

        if (timestamp >= vestingTierInfo.vestingEndTime) {
            return vestingTotalAmount;
        }

        uint256 beforeLastSegmentAmount = vestingTotalAmount.ratio(
            vestingSettings.vestingDuration -
                (vestingSettings.vestingDuration % vestingSettings.unlockStep),
            vestingSettings.vestingDuration
        );
        uint256 segmentsTotal = vestingSettings.vestingDuration / vestingSettings.unlockStep;
        uint256 segmentsBefore = (timestamp - vestingTierInfo.vestingStartTime) /
            vestingSettings.unlockStep;

        return beforeLastSegmentAmount.ratio(segmentsBefore, segmentsTotal);
    }
}
