// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { ERC1155Holder } from "openzeppelin/token/ERC1155/utils/ERC1155Holder.sol";
import { VaultV2 } from "y2k-earthquake/src/v2/VaultV2.sol";

import { IInsuranceProvider } from  "../interfaces/IInsuranceProvider.sol";
import { IStakingRewards } from  "../interfaces/IStakingRewards.sol";
import { IAddressUpdater } from "../interfaces/IAddressUpdater.sol";

contract Y2KEarthquakeV2InsuranceProvider is IInsuranceProvider, Ownable, ERC1155Holder {
    using SafeERC20 for IERC20;

    event Purchased(uint256 indexed epochId, uint256 amount);
    event ClaimedPayout(uint256 indexed epochId, uint256 amount);
    event ClaimedRewards(uint256 amount);
    event SetStakingRewards(address stakingRewards);
    event SetStakingRewardsUpdater(address stakingRewardsUpdater);

    VaultV2 public vault;

    IERC20 public override insuredToken;
    IERC20 public override paymentToken;
    IERC20 public override constant rewardToken = IERC20(0x65c936f008BC34fE819bce9Fa5afD9dc2d49977f);  // Y2K token

    IStakingRewards public stakingRewards;
    IAddressUpdater public stakingRewardsUpdater;

    address public immutable beneficiary;

    uint256 public claimedEpochIndex;

    constructor(address vault_, address beneficiary_) {
        vault = VaultV2(vault_);
        insuredToken = IERC20(address(vault.token()));
        paymentToken = IERC20(address(vault.asset()));
        beneficiary = beneficiary_;

        claimedEpochIndex = 0;
    }

    function currentEpoch() public override view returns (uint256) {
        uint256 len = vault.getEpochsLength();

        if (len == 0) return 0;

        for (int256 i = int256(len - 1); i >= 0; i--) {
            uint256 epochId = vault.epochs(uint256(i));

            (uint40 epochBegin, uint40 epochEnd, ) = vault.getEpochConfig(epochId);

            if (block.timestamp > epochEnd) {
                break;
            }

            if (block.timestamp >= epochBegin) {
                return epochId;
            }
        }

        return 0;
    }

    function followingEpoch(uint256 epochId) public view returns (uint256) {
        uint256 len = vault.getEpochsLength();
        if (len <= 1) return 0;

        uint256 i = len - 2;
        while (true) {
            if (vault.epochs(i) == epochId) {
                return vault.epochs(i + 1);
            }

            if (i == 0) break;
            i--;
        }
        return 0;
    }

    function nextEpoch() public override view returns (uint256) {
        uint256 len = vault.getEpochsLength();
        if (len == 0) return 0;
        return followingEpoch(currentEpoch());
    }

    function epochDuration() external override view returns (uint256) {
        uint256 id = currentEpoch();
        (uint40 epochBegin, uint40 epochEnd, ) = vault.getEpochConfig(id);
        return epochEnd - epochBegin;
    }

    function isNextEpochPurchasable() public override view returns (bool) {
        uint256 id = nextEpoch();
        (uint40 epochBegin, , ) = vault.getEpochConfig(id);
        return id > 0 && block.timestamp <= epochBegin;
    }

    function nextEpochPurchased() external view returns (uint256) {
        return vault.balanceOf(address(this), nextEpoch());
    }

    function currentEpochPurchased() external view returns (uint256) {
        return vault.balanceOf(address(this), currentEpoch());
    }

    function _pendingPayoutForEpoch(uint256 epochId) internal view returns (uint256) {
        if (vault.finalTVL(epochId) == 0) return 0;
        uint256 shares = vault.balanceOf(address(this), epochId);
        return vault.previewWithdraw(epochId, shares);
    }

    function pendingPayouts() external override view returns (uint256) {
        uint256 pending = 0;

        uint256 len = vault.getEpochsLength();
        for (uint256 i = claimedEpochIndex; i < len; i++) {
            pending += _pendingPayoutForEpoch(vault.epochs(i));
        }
        return pending;
    }

    function pendingRewards() external override view returns (uint256) {
        if (address(stakingRewards) == address(0)) return 0;
        return stakingRewards.earned(address(this));
    }

    function purchaseForNextEpoch(uint256 amountPremium) external onlyOwner override {
        require(isNextEpochPurchasable(), "YEIP: cannot purchase next epoch");
        paymentToken.safeTransferFrom(msg.sender, address(this), amountPremium);
        paymentToken.safeApprove(address(vault), amountPremium);
        uint256 epochId = nextEpoch();
        vault.deposit(epochId, amountPremium, address(this));

        emit Purchased(epochId, amountPremium);
    }

    function _claimPayoutForEpoch(uint256 epochId) internal returns (uint256) {
        if (vault.balanceOf(address(this), epochId) == 0) return 0;

        uint256 amount = vault.withdraw(epochId,
                                        vault.balanceOf(address(this), epochId),
                                        address(this),
                                        address(this));

        emit ClaimedPayout(epochId, amount);

        return amount;
    }

    function claimPayouts(uint256 epochId) external override onlyOwner returns (uint256) {
        require(epochId == vault.epochs(claimedEpochIndex), "YEIP: must claim sequentially");
        uint256 amount = _claimPayoutForEpoch(epochId);
        if (amount > 0) paymentToken.safeTransfer(beneficiary, amount);
        claimedEpochIndex++;
        return amount;
    }

    function setStakingRewards(address stakingRewards_) external onlyOwner {
        stakingRewards = IStakingRewards(stakingRewards_);

        emit SetStakingRewards(stakingRewards_);
    }

    function setStakingRewardsUpdater(address stakingRewardsUpdater_) external onlyOwner {
        stakingRewardsUpdater = IAddressUpdater(stakingRewardsUpdater_);

        emit SetStakingRewardsUpdater(stakingRewardsUpdater_);
    }

    function updateStakingRewardsAddress() external {
        require(address(stakingRewardsUpdater) != address(0), "YEIP: zero updater contract");
        stakingRewards = IStakingRewards(stakingRewardsUpdater.getAddress());

        emit SetStakingRewards(address(stakingRewards));
    }

    function claimRewards() external override onlyOwner returns (uint256) {
        require (address(stakingRewards) != address(0), "YEIP: zero rewards contract");
        stakingRewards.getReward();
        uint256 amount = rewardToken.balanceOf(address(this));
        rewardToken.safeTransfer(beneficiary, amount);

        emit ClaimedRewards(amount);

        return amount;
    }
}
