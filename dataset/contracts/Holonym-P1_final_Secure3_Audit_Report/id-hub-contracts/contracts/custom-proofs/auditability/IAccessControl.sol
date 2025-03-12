// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
interface IAccessControlContract {
    // Requiring C1X makes it easier for the MPC network down the road, it's convenient to have something bound to the encryption like C1X in the the accesControlConditions so it can easily be signed
   function hasAccess(address addr, bytes32 tagId, uint256 c1x) external view returns (bool hasAccess);
}