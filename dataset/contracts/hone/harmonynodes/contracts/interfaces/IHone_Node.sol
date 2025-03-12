// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ICommonStruct.sol";

interface IHoneNode is ICommonStruct {

   function claimRewards(
      address sender_
   ) external returns(uint256);

   function getClaimableRewards(address user_) external view returns(uint256);

   function createNode(
      address sender_,
      uint8 createNodeType_,
      uint256 curTime_,
      uint256 deadline_
   ) external;

   function upgradeNode(
      address sender_,
      uint8 nodeType_,
      uint256[] memory useNodes_,
      uint256 deadline_,
      uint256 curTime_
   ) external;

   function payMaintenanceFee(
      address sender_,
      uint256 nodeID_
   ) external returns(uint256);

   function payAllMaintenanceFee(
      address sender_
   ) external returns(uint256);

   function listLendOffer(
      address sender_,
      uint256 nodeIndex_,
      uint256 amount_,
      uint16 months_
   ) external returns(uint8 nodeType);

   function closeLendOffer(
      address sender_,
      uint256 nodeIndex_
   ) external;

   function acceptLendOffer(
      address sender_,
      address lendOwner_,
      uint256 lendNodeIndex_,
      uint256 curTime_,
      uint16 lendMonths_,
      uint8 lendNodeType_
   ) external;

   function getNodeCount(
      address userAddress_
   ) external view returns(uint256);

   function getNodes(
      address userAddress_
   ) external view returns(NodeDispInfo[] memory);

}