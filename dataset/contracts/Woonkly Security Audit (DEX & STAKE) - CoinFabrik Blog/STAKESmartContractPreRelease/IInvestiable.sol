// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;


interface IInvestable{
    function getFreezeCount() external view returns(uint256) ;
    function getLastIndexFreezes() external view  returns(uint256);     
    function FreezeExist(address account) external  view  returns(bool);
    function FreezeIndexExist(uint256 index) external  view  returns(bool);
    function newFreeze(address account,uint256 amount,uint256 date ) external returns(uint256);
    function removeFreeze(address account) external;
    function getFreeze(address account) external  view  returns( uint256 , uint256 , uint256 );
    function getFreezeByIndex(uint256 index) external  view  returns( uint256 , uint256 , uint256 );
    function getAllFreeze() external  view  returns(uint256[] memory, address[] memory ,uint256[] memory , uint256[] memory , uint256[] memory );
    function updateFund(address account,uint256 withdraw) external  returns(bool);
    function canWithdrawFunds(address account,uint256 withdraw,uint256 currentFund) external  view  returns(bool);
    function howMuchCanWithdraw(address account,uint256 currentFund) external  view  returns(uint256);
        
}