// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
@notice AddressBook records the multi-signature wallet address of the underlying asset and 
the correspondence between the user's Ethereum address and other asset addresses
 */
contract AddressBook is Ownable {
    mapping(string => string) public assetMultiSignAddress;

    function setAssetMultiSignAddress(string memory symbol, string memory addr) external onlyOwner{
        assetMultiSignAddress[symbol] = addr;
    }
}
