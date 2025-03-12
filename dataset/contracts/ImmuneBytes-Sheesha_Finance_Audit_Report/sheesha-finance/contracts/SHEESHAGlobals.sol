// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SHEESHAGlobals is Ownable {

    address public SHEESHATokenAddress;
    address public SHEESHAGlobalsAddress;
    address public SHEESHAVaultAddress;
    address public SHEESHAVaultLPAddress;
    address public SHEESHAWETHUniPair;
    address public UniswapFactory;

    function initialize(address _SHEESHAWETHUniPair, address _SHEESHAToken, address _SHEESHAVaultLP, address _SHEESHAVault, address _uniFactory) public onlyOwner {
        SHEESHATokenAddress = _SHEESHAToken;
        SHEESHAGlobalsAddress = address(this);
        SHEESHAVaultAddress = _SHEESHAVault;
        UniswapFactory = _uniFactory;
        SHEESHAWETHUniPair = _SHEESHAWETHUniPair;
        SHEESHAVaultLPAddress = _SHEESHAVaultLP;
    }

    function setSheeshaToken(address _SHEESHAToken) public onlyOwner {
        SHEESHATokenAddress = _SHEESHAToken;
    }

    function setSheeshaVaultAddress(address _SHEESHAVault) public onlyOwner {
        SHEESHAVaultAddress = _SHEESHAVault;
    }

    function setSheeshaVaultLPAddress(address _SHEESHAVaultLP) public onlyOwner {
        SHEESHAVaultLPAddress = _SHEESHAVaultLP;
    }

}