// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Roots is Ownable {    
    // Store historical roots in case root updates before a proof involving an old root is submitted 
    uint8 public constant ROOT_HISTORY_SIZE = 200; // This should be more than enough historical roots
   
    uint256[ROOT_HISTORY_SIZE] public recentRootsList; // NOTE: this will be *unorderded*
    mapping(uint256 => bool) public recentRootsMap;

    // // At which index in recentRootsList was the current root inserted:
    uint8 currentRootIdx = 0;
    // uint8 oldestRootIdx = 0;
    // uint8 newestRootIdx = 0;

    // NOTE: owner will later be a smart contract that allows for more decentralized mechanism, like multisig or ZKP that the root is correct
    function addRoot(uint256 root) public onlyOwner {
        // Cycle through the recent root list, replacing the oldest root with the newest root
        currentRootIdx = (currentRootIdx + 1) % ROOT_HISTORY_SIZE;  
        recentRootsMap[recentRootsList[currentRootIdx]] = false;
        recentRootsList[currentRootIdx] = root;
        recentRootsMap[recentRootsList[currentRootIdx]] = true;
    }
    
    function mostRecentRoot() public view returns (uint256 root) {
        return recentRootsList[currentRootIdx];
    }

    function rootIsRecent(uint256 root) public view returns (bool isRecent) {
        return recentRootsMap[root];
    }

}