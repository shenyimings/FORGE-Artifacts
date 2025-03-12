// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/V4/PeanutV4.sol";

contract DeploymentGlobals {
    mapping(uint256 => address) public ecoAddressByChain;

    constructor() {
        // Mainnet and its testnets
        ecoAddressByChain[1] = 0x8dBF9A4c99580fC7Fd4024ee08f3994420035727;
        ecoAddressByChain[5] = 0x8dBF9A4c99580fC7Fd4024ee08f3994420035727;
        ecoAddressByChain[11155111] = 0x8dBF9A4c99580fC7Fd4024ee08f3994420035727;
        ecoAddressByChain[17000] = 0x8dBF9A4c99580fC7Fd4024ee08f3994420035727;

        // Optimism and its goerli
        ecoAddressByChain[10] = 0xe7BC9b3A936F122f08AAC3b1fac3C3eC29A78874;
        ecoAddressByChain[420] = 0xe7BC9b3A936F122f08AAC3b1fac3C3eC29A78874;
    }
}
