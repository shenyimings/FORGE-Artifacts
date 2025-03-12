// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ReaderDatatype } from "../ReaderDatatype.sol";

interface IDLPRush {
    struct UserInfo {
        uint256 converted;
        uint256 factor;
    }
    
    function totalConverted() external view returns (uint256);
    function userInfos(address _user) external view returns(UserInfo memory); 
}

interface IVlmgp
{
    function totalLocked() external view returns (uint256);
    function getUserTotalLocked(address _user) external view returns (uint256);
}

interface IBurnEventManager
{
    function eventInfos(uint256 _eventId) external view returns( uint256, string memory, uint256, bool); 
    function userMgpBurnAmountForEvent(address _user, uint256 evntId) external view returns(uint256);
}

interface IRadpieReader is ReaderDatatype
{
    function getRadpieInfo(address account) external view returns (RadpieInfo memory);
    function getRadpiePoolInfo(
        uint256 poolId,
        address account,
        RadpieInfo memory systemInfo
    ) external view returns (RadpiePool memory);
    function getDlpPrice() external view returns (uint256);
}

interface IPendleRushV4
{
    function totalAccumulated() external view returns (uint256);
    function userInfos(address _user) external view returns(uint256, uint256); 

}


interface IDlpHelper
{
   	function getPrice() external view returns (uint256 priceInEth);
}
