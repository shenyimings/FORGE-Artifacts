// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ICommonStruct {

   struct TimeInfo {
      uint256 createdTime;
      uint256 lastClaimTime;
      uint256 deadline;
   }

   struct RentStatus {
      address renter;
      bool lendStatus;
      bool offerStatus;
      bool borrowStatus;
      uint256 rentTime;
      uint256 rentDeadline;
   }

   struct NodeInfo {
      uint8 nodeType;
      bool ownable;
      bool burned;
      TimeInfo timeLine;
      RentStatus rentStatus;
      uint256 brokenClaimCnt;
   }

   struct NodeDispInfo {
      uint8 nodeType;
      bool lendStatus;
      bool borrowStatus;
      uint256 deadline;
      uint256 rentDeadline;
      uint256 nodeIndex;
   }

   struct LendInfo {
      address owner;
      uint8 nodeType;
      uint256 nodeIndex;
      uint256 amount;
      uint256 offerIndex;
      uint16 months;
      bool forLend;
   }
}