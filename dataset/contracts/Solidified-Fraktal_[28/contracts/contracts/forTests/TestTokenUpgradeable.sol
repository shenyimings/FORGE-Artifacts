// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';

contract TestTokenUpgradeable is ERC721Upgradeable {
    uint256 index;
    constructor() initializer {
      index = 0;
    }

    function init(string calldata name, string calldata symbol)
        external
        initializer
    {
        /* console.log(
            'Deploying TestToken with name: %s and symbol: %s',
            name,
            symbol
        ); */
        __ERC721_init(name, symbol);
    }

    function mint() external {
        index ++;
        /* console.log("Minting tokenId '%s' to '%s'", index, _msgSender()); */
        _safeMint( _msgSender(), index);
    }
}
