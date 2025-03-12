// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IFeeManager {
    function doCutDepositFee(address token, uint256 amount)
        external
        returns (uint256);

    function doCutWithdrawFee(address token, uint256 amount)
        external
        returns (uint256);

    function doCutRewardsFee(address token, uint256 amount)
        external
        returns (uint256);

    function doCutVaultWithdrawFee(address token, uint256 amount)
        external
        returns (uint256);
}
