// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

///@title Frens Art
///@author 0xWildhare and Frens Team
///@dev generates the svg artwork for the NFT by compiling strings from various contracts

import "./interfaces/IFrensMetaHelper.sol";
import "./interfaces/IPmFont.sol";
import "./interfaces/IFrensLogo.sol";
import "./interfaces/IWaves.sol";
import "./interfaces/IFrensStorage.sol";
//import "hardhat/console.sol";

contract FrensArt {

    IFrensStorage frensStorage;
    
    constructor(
        IFrensStorage frensStorage_
    ) {
        frensStorage = frensStorage_;
    }

    function renderTokenById(uint256 id) public view returns (string memory) {
        IFrensMetaHelper frensMetaHelper = IFrensMetaHelper(frensStorage.getAddress(keccak256(abi.encodePacked("contract.address", "FrensMetaHelper"))));
        IPmFont pmFont = IPmFont(frensStorage.getAddress(keccak256(abi.encodePacked("contract.address", "PmFont"))));
        IWaves waves = IWaves(frensStorage.getAddress(keccak256(abi.encodePacked("contract.address", "Waves"))));
        IFrensLogo frensLogo = IFrensLogo(frensStorage.getAddress(keccak256(abi.encodePacked("contract.address", "FrensLogo"))));
        string memory depositString = frensMetaHelper.getDepositStringForId(id);
        string memory pool = frensMetaHelper.getPoolString(id);
        bytes memory permanentMarker = pmFont.getPmFont();
        bytes memory logo = frensLogo.getLogo();
        bytes memory wavesGraphic = waves.getWaves();
        string memory render = string(
            abi.encodePacked(
                "<defs>",
                '<linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">',
                '<stop offset="0%" style="stop-color:#3f19ee;stop-opacity:1" />',
                '<stop offset="100%" style="stop-color:#54dae0;stop-opacity:1" />',
                "</linearGradient>",
                permanentMarker,
                '<rect height="400" width="400" fill="url(#grad1)" />',
                logo,
                wavesGraphic,
                '<text font-size="15.5" x="200" y="163" text-anchor="middle" font-family="Sans,Arial" letter-spacing="6" fill="white">',
                "DEPOSIT",
                "</text>",
                '<text font-size="45" x="200" y="212" text-anchor="middle"  font-weight="910" font-family="Sans,Arial" letter-spacing="-1" fill="white">',
                depositString,
                " ETH ",
                "</text>",
                '<text font-size="18.7" x="200" y="243" text-anchor="middle" font-family="Permanent Marker" fill="white">',
                "FRENS POOL STAKE",
                "</text>",
                '<rect x="27" y="345" height="30" width="346" fill="#4554EA" opacity=".4" />',
                '<text font-size="10" x="200" y="365" text-anchor="middle" font-weight="bold" font-family="Sans,Arial" fill="white">',
                pool,
                "</text>"
            )
        );

        return render;
    }
}
