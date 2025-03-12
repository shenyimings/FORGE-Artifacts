// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IFeeRouter {
    function pcFee(address _account, address _token, uint256 _totalAmount, uint256 _discountRebateAmount) external payable returns (uint256);

    function claimableFeeReserves( )  external view returns (uint256);
    function claimFeeToken(address _token) external returns (uint256);
    function claimFeeReserves( ) external returns (uint256) ;

    function feeReservesRecord(uint256 _day) external view returns (uint256);
    function claimPLPReward() external returns (uint256);
}