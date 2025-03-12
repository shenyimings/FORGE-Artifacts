// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

interface IAboatToken {
    function canMintNewCoins(uint256 _amount) external view returns(bool); 
    function liquidityPair() external view returns(address);
    function mint(address _to, uint256 _amount) external;
}