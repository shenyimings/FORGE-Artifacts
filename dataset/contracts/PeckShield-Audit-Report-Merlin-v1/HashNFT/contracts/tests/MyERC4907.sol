// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "double-contracts/contracts/4907/ERC4907.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MyERC4907 is ERC4907 {
    using Counters for Counters.Counter;
    
    Counters.Counter private _counter;

    constructor(string memory name_, string memory symbol_) ERC4907(name_, symbol_) {}

    function mint(address to) public returns(uint256 tokenId) {
        tokenId = _counter.current();
        _safeMint(to, tokenId);
        _counter.increment();
    }

}