// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../BEP20YAY.sol";

contract ERC20CappedMock is BEP20YAY {
    constructor() public BEP20YAY() {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}
