pragma solidity ^0.8.0.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./Interfaces/IAccessControlNFT.sol";

library LibRoles {

    function isTierEnabled(IAccessControlNFT.RoleData storage role, IAccessControlNFT.Tier tier) internal view returns(bool) {
        return role.feeByTier[tier] > 0;
    }
    
    function roleIndex(IAccessControlNFT.User storage user, uint8 roleId) internal view returns(uint256) {
        uint256 index = user.indexByRole[roleId];
        if(user.userRoleDataArray.length == 0) return type(uint256).max;
        if(user.userRoleDataArray[0].roleId == roleId) return 0;
        return index == 0 ? type(uint256).max : index;
    }

    function bestTierOf(IAccessControlNFT.User storage user, uint8 roleId) internal view returns(IAccessControlNFT.Tier) {
        return user.userRoleDataArray[user.indexByRole[roleId]].tier;
    }

}