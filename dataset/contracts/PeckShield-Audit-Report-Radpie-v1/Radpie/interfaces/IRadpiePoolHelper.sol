// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IRadpiePoolHelper {
    function totalStaked(address _asset) external view returns (uint256);

    function balance(address _asset, address _address) external view returns (uint256);

    function withdrawAsset(address _asset, uint256 _amount) external;

    function harvest(address _asset) external;

    function setOperator(address _address, bool _value) external;
}
