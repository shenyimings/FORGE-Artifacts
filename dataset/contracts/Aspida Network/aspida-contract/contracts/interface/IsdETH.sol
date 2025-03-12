// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IsdETH {
    function deposit(uint256 _assets, address _receiver) external returns (uint256 _shares);

    function withdraw(uint256 _assets, address _receiver, address _owner) external returns (uint256 _shares);

    function redeem(uint256 _shares, address _receiver, address _owner) external returns (uint256 _assets);
}
