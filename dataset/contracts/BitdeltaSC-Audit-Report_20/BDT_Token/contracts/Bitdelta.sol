// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BitDelta is ERC20, Ownable {
   
  constructor( 
        // Receives an array of 6 addresses to which initial token amounts will be minted
        address[6] memory addresses
        ) ERC20("BitDelta","BDT") {
        // Minting tokens to the supplied addresses with respective purposes
        _mint(addresses[0], 600_000_000 * (10 ** decimals()));//Circulating_Supply
        _mint(addresses[1], 480_000_000 * (10 ** decimals()));//Users_Onboarding_And_Staking_Rewards
        _mint(addresses[2], 480_000_000 * (10 ** decimals()));//Marketing
        _mint(addresses[3], 240_000_000 * (10 ** decimals()));//Reasearch_And_Development
        _mint(addresses[4], 240_000_000 * (10 ** decimals()));//Team
        _mint(addresses[5], 360_000_000 * (10 ** decimals()));//Platform_Governance
  }

}
