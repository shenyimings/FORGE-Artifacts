// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IveMNT {
    function whitelisted(address _address) external view returns (bool);

    function takeVeMnt(address from, uint256 percent) external returns (uint256, uint256, uint256);
    
    function releaseVeMnt(address from, uint256 mntLpAmount, uint256 veMntAmount, uint256 veMntRate) external returns (bool);

    function exchangeVeMnt(address from, address to, uint256 mntLpAmount, uint256 veMntAmount, uint256 veMntRate) external returns (bool);
}