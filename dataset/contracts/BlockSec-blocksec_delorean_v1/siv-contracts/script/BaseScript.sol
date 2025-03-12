// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "forge-std/Script.sol";

contract BaseScript is Script {
    uint256 pk;
    address deployerAddress;

    address public glpTracker = 0x4e971a87900b931fF39d1Aad67697F49835400b6;
    address public stakedGLP = 0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf;

    address public constant arbitrumWeth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant arbitrumSequencer = 0xFdB631F5EE196F0ed6FAa767959853A9F217697D;

    address public constant arbitrumUSDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public constant arbitrumUSDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address public constant arbitrumFrax = 0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F;
    address public constant arbitrumDai  = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    address public constant y2kToken = 0x65c936f008BC34fE819bce9Fa5afD9dc2d49977f;
    address public constant y2kVaultFactory = 0x984E0EB8fB687aFa53fc8B33E12E04967560E092;

    function eq(string memory str1, string memory str2) public pure returns (bool) {
        return keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2));
    }

    function init() public {
        if (eq(vm.envString("NETWORK"), "arbitrum")) {
            console.log("Using Arbitrum mainnet private key");
            pk = vm.envUint("ARBITRUM_PRIVATE_KEY");
            deployerAddress = vm.envAddress("ARBITRUM_DEPLOYER_ADDRESS");
        } else {
            console.log("Using localhost private key");
            pk = vm.envUint("LOCALHOST_PRIVATE_KEY");
            deployerAddress = vm.envAddress("LOCALHOST_DEPLOYER_ADDRESS");
        }
    }
}
