// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IRadpieReceiptToken {

    function assetPerShare() external view returns(uint256);
}