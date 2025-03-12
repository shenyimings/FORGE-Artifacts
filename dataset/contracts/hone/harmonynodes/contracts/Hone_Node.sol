// SPDX-License-Identifier: MIT

import "./interfaces/IHONE.sol";
import "./interfaces/IHone_Node.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./HarmonyLibrary.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "hardhat/console.sol";

pragma solidity ^0.8.7;

contract HoneNode is Ownable, ReentrancyGuard, IHoneNode {
   mapping(address => NodeInfo[]) private userInfos;
   uint8[] private breakDays = [100, 87, 75, 58];
   uint8[] private nodePrice = [10, 20, 50, 100];
   uint8[] private rewardPercent = [100, 115, 135, 175];    // * 1e2
   uint8[] private maintenanceFee = [10, 20, 30, 45];

   function claimRewards(
      address sender_
   ) external onlyOwner override returns(uint256) {
      require (sender_ != address(0), 'zero address');
      require (userInfos[sender_].length > 0, 'no node');

      uint256 curTime = block.timestamp;
      for (uint256 i = 0; i < userInfos[sender_].length; i ++) {
         uint256 brokendDays = curTime - userInfos[sender_][i].timeLine.createdTime;
         brokendDays = brokendDays / 1 days;
         if (brokendDays > breakDays[userInfos[sender_][i].nodeType]) {
            userInfos[sender_][i].brokenClaimCnt ++;
         }
      }

      uint256 rewards = _calcClaimableRewards(sender_,curTime);

      for (uint256 i = 0; i < userInfos[sender_].length; i ++) {
         NodeInfo memory node = userInfos[sender_][i];

         if (node.timeLine.deadline >= curTime) {
            userInfos[sender_][i].timeLine.lastClaimTime = curTime;
         } else {
            if (node.timeLine.deadline != node.timeLine.lastClaimTime) {
               userInfos[sender_][i].timeLine.lastClaimTime = node.timeLine.deadline;
            }
         }

         if (node.rentStatus.lendStatus == true) {
            if (node.rentStatus.rentDeadline < curTime) {
               userInfos[sender_][i].rentStatus.lendStatus = false;   
            }
         }
      }

      return rewards;
   }

   function createNode(
      address sender_,
      uint8 createNodeType_,
      uint256 curTime_,
      uint256 deadline_
   ) external onlyOwner override {
      _createNode(sender_, createNodeType_, curTime_, deadline_);
   }

   function upgradeNode(
      address sender_,
      uint8 nodeType_,
      uint256[] memory useNodes_,
      uint256 deadline_,
      uint256 curTime_
   ) external onlyOwner override {
      uint256 nodeAmount = 0;

      for (uint256 i = 0; i < useNodes_.length; i ++) {
         require (useNodes_[i] < userInfos[sender_].length, 'not exist node');
         require (
            userInfos[sender_][useNodes_[i]].rentStatus.lendStatus == false && 
            userInfos[sender_][useNodes_[i]].rentStatus.offerStatus == false &&
            userInfos[sender_][useNodes_[i]].rentStatus.borrowStatus == false,
            'rent node exist'
         );
         nodeAmount += nodePrice[userInfos[sender_][useNodes_[i]].nodeType];
         userInfos[sender_][useNodes_[i]].burned = true;
      }

      require (nodeAmount >= nodePrice[nodeType_], 'wrong cost');
      _createNode(sender_, nodeType_, curTime_, deadline_);
   }

   function payMaintenanceFee(
      address sender_,
      uint256 nodeID_
   ) external onlyOwner override returns(uint256 desiredAmount) {
      require (sender_ != address(0), 'zero address');
      require (
         userInfos[sender_].length > nodeID_ ||
         HarmonyLibrary._getLendStatus(
            userInfos[sender_][nodeID_].rentStatus, 
            block.timestamp
         ) == false, 
         'wrong node'
      );

      userInfos[sender_][nodeID_].timeLine.deadline += 30 days;
      desiredAmount = uint256(maintenanceFee[userInfos[sender_][nodeID_].nodeType]) * 1e6;
   }

   function payAllMaintenanceFee(
      address sender_
   ) external onlyOwner override returns(uint256 desiredAmount) {
      require (sender_ != address(0), 'zero address');
      if (userInfos[sender_].length == 0) {
         return 0;
      }
      desiredAmount = 0;
      for (uint256 i = 0; i < userInfos[sender_].length; i ++) {
         if (
            userInfos[sender_][i].burned == false &&
            HarmonyLibrary._getLendStatus(
               userInfos[sender_][i].rentStatus, 
               block.timestamp
            ) == false
         ) {
            userInfos[sender_][i].timeLine.deadline += 30 days;
            desiredAmount += uint256(maintenanceFee[userInfos[sender_][i].nodeType]) * 1e6;
         }
      }
   }

   function listLendOffer(
      address sender_,
      uint256 nodeIndex_,
      uint256 amount_,
      uint16 months_
   ) external onlyOwner override returns(uint8 nodeType) {
      require (sender_ != address(0), 'zero address');
      require (amount_ > 0 && months_ > 0 && userInfos[sender_].length > nodeIndex_, 'wrong offer');
      require (userInfos[sender_][nodeIndex_].rentStatus.offerStatus == false, 'already listed');
      require (userInfos[sender_][nodeIndex_].timeLine.deadline > block.timestamp, 'dead node');

      userInfos[sender_][nodeIndex_].rentStatus.offerStatus = true;

      return userInfos[sender_][nodeIndex_].nodeType;  
   }

   function closeLendOffer(
      address sender_,
      uint256 nodeIndex_
   ) external onlyOwner override {
      userInfos[sender_][nodeIndex_].rentStatus.offerStatus = false;
   }

   function acceptLendOffer(
      address sender_,
      address lendOwner_,
      uint256 lendNodeIndex_,
      uint256 curTime_,
      uint16 lendMonths_,
      uint8 lendNodeType_
   ) external onlyOwner override {

      userInfos[sender_].push(NodeInfo({
         nodeType: lendNodeType_,
         ownable: false,
         timeLine: TimeInfo({
            createdTime: curTime_,
            lastClaimTime: curTime_,
            deadline: curTime_ + 30 days
         }),
         rentStatus: RentStatus({
            renter: lendOwner_,
            lendStatus: false,
            offerStatus: false,
            borrowStatus: true,
            rentTime: curTime_,
            rentDeadline: curTime_ + lendMonths_ * 30 days
         }),
         brokenClaimCnt: 0,
         burned: false
      }));

      userInfos[lendOwner_][lendNodeIndex_].rentStatus.rentTime = curTime_;
      userInfos[lendOwner_][lendNodeIndex_].rentStatus.rentDeadline = curTime_ + lendMonths_ * 30 days;
      userInfos[lendOwner_][lendNodeIndex_].rentStatus.lendStatus = true;
      userInfos[lendOwner_][lendNodeIndex_].rentStatus.offerStatus = false;
   }

   function getClaimableRewards(
      address user_
   ) external onlyOwner view override returns(uint256) {
      return _calcClaimableRewards(user_, block.timestamp);
   }

   function getNodeCount(
      address userAddress_
   ) public view onlyOwner override returns(uint256) {
      require (userAddress_ != address(0), 'wrong user');
      uint256 cnt = 0;
      uint256 length = userInfos[userAddress_].length;
      for (uint256 i = 0; i < length; i ++) {
         if (userInfos[userAddress_][i].burned == false) {
            cnt ++;
         }
      }
      return cnt;
   }

   function getNodes(
      address userAddress_
   ) external view onlyOwner override returns(NodeDispInfo[] memory) {
      uint256 cnt = getNodeCount(userAddress_);
      uint256 index = 0;
      NodeDispInfo[] memory infos = new NodeDispInfo[](cnt);
      for (uint256 i = 0; i < userInfos[userAddress_].length; i ++) {
         if (userInfos[userAddress_][i].burned == false) {
            infos[index ++] = NodeDispInfo({
               nodeType: userInfos[userAddress_][i].nodeType,
               lendStatus: userInfos[userAddress_][i].rentStatus.lendStatus,
               borrowStatus: userInfos[userAddress_][i].rentStatus.borrowStatus,
               deadline: userInfos[userAddress_][i].timeLine.deadline,
               rentDeadline: userInfos[userAddress_][i].rentStatus.rentDeadline,
               nodeIndex: i
            });
         }
      }

      return infos;
   }

   function _calcClaimableRewards(
      address user_, 
      uint256 curTime_
   ) internal view returns(uint256) {
      uint256 claimableRewards = 0;

      for (uint256 i = 0; i < userInfos[user_].length; i ++) {
         NodeInfo memory node = userInfos[user_][i];
         uint256 curTime = node.timeLine.deadline > curTime_ ? curTime_ : node.timeLine.deadline;

         uint256 originReward = uint256(nodePrice[node.nodeType]) * 1e18 * uint256(rewardPercent[node.nodeType]) / 1e4;
         uint256 curReward = HarmonyLibrary._getRewardAmount(
            nodePrice[node.nodeType],
            rewardPercent[node.nodeType],
            node.brokenClaimCnt
         );

         if (node.rentStatus.lendStatus == true) {
            claimableRewards += HarmonyLibrary._getLendReward(
               node.timeLine.lastClaimTime,
               node.rentStatus.rentTime,
               node.rentStatus.rentDeadline,
               curTime,
               node.timeLine.createdTime + breakDays[node.nodeType] * 1 days,
               originReward,
               curReward
            );
         } else if (node.rentStatus.borrowStatus == true) {
            if (curTime_ <= node.rentStatus.rentDeadline) {
               claimableRewards += HarmonyLibrary._getGeneralReward(
                  node.timeLine.lastClaimTime,
                  node.timeLine.createdTime + breakDays[node.nodeType] * 1 days,
                  curTime,
                  originReward,
                  curReward
               );
            }
         } else if (node.ownable == true) {
            claimableRewards += HarmonyLibrary._getGeneralReward(
               node.timeLine.lastClaimTime,
               node.timeLine.createdTime + breakDays[node.nodeType] * 1 days,
               curTime,
               originReward,
               curReward
            );
         }
      }

      return claimableRewards;
   }

   function _createNode(
      address owner_, 
      uint8 nodeType_, 
      uint256 curTime_, 
      uint256 deadline_
   ) internal {
      userInfos[owner_].push(NodeInfo({
         nodeType: nodeType_,
         ownable: true,
         timeLine: TimeInfo({
            createdTime: curTime_,
            lastClaimTime: curTime_,
            deadline: curTime_ + deadline_
         }),
         rentStatus: RentStatus({
            renter: address(0),
            lendStatus: false,
            offerStatus: false,
            borrowStatus: false,
            rentTime: 0,
            rentDeadline: 0
         }),
         brokenClaimCnt: 0,
         burned: false
      }));
   }
}