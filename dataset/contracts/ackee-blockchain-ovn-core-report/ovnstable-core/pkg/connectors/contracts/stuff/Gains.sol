// SPDX-License-Identifier: agpl-3.0
pragma solidity  >=0.8.0;

interface GainsVault {

    struct User{
        uint256 daiDeposited;
        uint256 maxDaiDeposited;
        uint256 withdrawBlock;
        uint256 debtDai;
        uint256 debtMatic;
    }


    function depositDai(uint256 _amount) external;

    function withdrawDai(uint256 _amount) external;
    function pendingRewardDai() external view returns(uint);

    function harvest() external;
    function users(address user) external view returns (User memory);
}
