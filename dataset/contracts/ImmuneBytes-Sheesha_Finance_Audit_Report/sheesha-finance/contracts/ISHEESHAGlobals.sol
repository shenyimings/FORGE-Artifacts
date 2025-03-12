// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

interface ISHEESHAGlobals {
    function SHEESHATokenAddress() external view returns (address);
    function SHEESHAGlobalsAddress() external view returns (address);
    function SHEESHAVaultAddress() external view returns (address);
    function SHEESHAVaultLPAddress() external returns (address);
    function SHEESHAWETHUniPair() external view returns (address);
    function UniswapFactory() external view returns (address);
}