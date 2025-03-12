//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

interface IInsuranceProvider {
    function beneficiary() external view returns (address);

    // ---- Token specification ---- //
    function insuredToken() external view returns (IERC20);
    function paymentToken() external view returns (IERC20);
    function rewardToken()  external view returns (IERC20);

    // ---- Epoch management ---- //
    function currentEpoch() external view returns (uint256);
    function followingEpoch(uint256) external view returns (uint256);
    function nextEpoch() external view returns (uint256);
    function isNextEpochPurchasable() external view returns (bool);
    function epochDuration() external view returns (uint256);

    function nextEpochPurchased() external view returns (uint256);
    function currentEpochPurchased() external view returns (uint256);

    function purchaseForNextEpoch(uint256 amountPremium) external;

    // ---- Payout management ---- //
    function pendingPayouts() external view returns (uint256);
    function claimPayouts(uint256 epochId) external returns (uint256);
    function pendingRewards() external view returns (uint256);
    function claimRewards() external returns (uint256);
}
