// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "./IFeeManager.sol";

interface IProtocolConfig {
    function depositFee() external view returns (uint256);

    function withdrawFee() external view returns (uint256);

    function rewardFee() external view returns (uint256);

    function maxSlippageOfClose() external view returns (uint256);

    function treasury() external view returns (address);

    function withdrawVaultFee() external view returns (uint256);

    function withdrawVaultFeeWindow() external view returns (uint256);

    function withdrawVaultFeeWindowStartTime() external view returns (uint256);

    function feeManager() external view returns (IFeeManager);
}
