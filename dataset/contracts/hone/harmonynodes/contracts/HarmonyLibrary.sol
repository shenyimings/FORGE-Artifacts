// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ICommonStruct.sol";
import "hardhat/console.sol";

library HarmonyLibrary {
   function _calcAmount(
      uint256 honeAmount_
   ) internal pure returns(
      uint256 liquidity,
      uint256 liquidityUSDC,
      uint256 rewardPoolAmount
   ) {
      uint256 burnAmount = honeAmount_ * 25 / 100;
      liquidity = honeAmount_ / 10;
      liquidityUSDC = liquidity * 22;
      rewardPoolAmount = honeAmount_ - burnAmount - liquidity;
   }

   function _getRewardAmount(
      uint8 nodePrice_,
      uint8 nodePercent_,
      uint256 brokenCount_
   ) internal pure returns(uint256 reward) {
      reward = uint256(nodePrice_) * 1e18 * uint256(nodePercent_) / 1e4;

      if (brokenCount_ > 0) {
         while (true) {
            if (brokenCount_ == 0) {
               break;
            }
            if (brokenCount_ >= 30) {
               brokenCount_ -= 30;
               reward = reward * 95**30 / 100**30;
            } else {
               reward = reward * 95**brokenCount_ / 100**brokenCount_;
               brokenCount_ = 0;
            }
         }
      }
   }

   function _getGeneralReward(
      uint256 lastClaimTime_,
      uint256 breakTime_,
      uint256 curTime_,
      uint256 originReward_,
      uint256 curReward_
   ) internal pure returns(uint256) {
      uint256 rewards = 0;
      if (lastClaimTime_ > curTime_) {
         return 0;
      }

      if (curTime_ < breakTime_) {
         rewards = (curTime_ - lastClaimTime_) * originReward_;
      } else {
         if (lastClaimTime_ < breakTime_) {
            rewards = (breakTime_ - lastClaimTime_) * originReward_ + 
            (curTime_ - breakTime_) * curReward_;
         } else {
            rewards = (curTime_ - lastClaimTime_) * curReward_;
         }
      }

      return rewards / 1 days;
   }

   function _getLendReward(
      uint256 lastClaimTime_,
      uint256 rentTime_,
      uint256 rentDeadline_,
      uint256 curTime_,
      uint256 breakTime_,
      uint256 originReward_,
      uint256 curReward_
   ) internal pure returns(uint256) {
      uint256 rewards = 0;

      if (lastClaimTime_ > curTime_) {
         return 0;
      }

      if (curTime_ < rentDeadline_) {
         if (lastClaimTime_ < rentTime_) {
            rewards = _getGeneralReward(
               lastClaimTime_, 
               breakTime_, 
               curTime_, 
               originReward_, 
               curReward_
            );  
         } else {
            rewards = 0;
         }
      } else {
         if (lastClaimTime_ < rentTime_) {
            rewards = _getGeneralReward(
               lastClaimTime_, 
               breakTime_, 
               curTime_, 
               originReward_, 
               curReward_
            );

            rewards += _getGeneralReward(
               rentDeadline_, 
               breakTime_, 
               curTime_, 
               originReward_, 
               curReward_
            );
         } else {
            rewards = _getGeneralReward(
               rentDeadline_, 
               breakTime_, 
               curTime_, 
               originReward_, 
               curReward_
            );
         }
      }

      return rewards / 1 days;
   }

   function _getLendStatus(
      ICommonStruct.RentStatus memory rentStatus_,
      uint256 curTime_
   ) internal pure returns(bool) {
      if (
         rentStatus_.lendStatus == false ||
         (rentStatus_.lendStatus == true && rentStatus_.rentDeadline <= curTime_)
      ) {
         return false;
      }

      return true;
   }
}