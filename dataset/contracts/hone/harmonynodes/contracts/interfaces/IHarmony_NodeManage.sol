// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./ICommonStruct.sol";

interface IHarmony_NodeMange is ICommonStruct {

   function setRewardPool(address rewardPool) external;
   function claimRewards() external;
   function createNode(uint256 honeAmount_, uint8 createNodeType_) external;
   function swapNode(uint256 tokenID_) external;
   function payMaintenanceFee(uint256 nodeID_) external;
   function payAllMaintenanceFee() external;
   function upgradeNode(
      uint8 nodeType_,
      uint256[] memory useNodes_
   ) external;
   function listLendOffer(uint256 nodeIndex_, uint256 amount_, uint16 months_) external;
   function closeLendOffer(uint256 offerIndex_) external;
   function acceptLendOffer(uint256 offerIndex_) external;
   function getNodeCount(address userAddress_) external view returns(uint256);
}