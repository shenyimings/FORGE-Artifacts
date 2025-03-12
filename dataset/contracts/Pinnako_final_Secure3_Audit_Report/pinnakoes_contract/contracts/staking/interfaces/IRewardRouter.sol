// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IRewardRouter {
    function getEUSDPoolInfo() external view returns (uint256[] memory);
    function stakeELPn(address _elp_n, uint256 _elpAmount) external returns (uint256);
    function unstakeELPn(address _elp_n, uint256 _tokenInAmount) external returns (uint256);
    function claimAll() external  returns ( uint256[] memory);
    function lvt() external view returns (uint256) ;
    function sellEUSD(address _token, uint256 _EUSDamount) external returns (uint256);
    function sellEUSDNative(uint256 _EUSDamount) external returns (uint256);
}
