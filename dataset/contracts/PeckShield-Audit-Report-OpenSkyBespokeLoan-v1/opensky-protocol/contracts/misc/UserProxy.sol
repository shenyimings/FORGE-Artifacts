// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract UserProxy is ERC721Holder {
    address public immutable owner;

    constructor() {
        owner = msg.sender;
    }

    function execute(address target, bytes memory data, uint256 value) external {
        require(msg.sender == owner, "ONLY_OWNER");
        (bool success, ) = target.call{value: value}(data);
        require(success, "LOW_LEVEL_CALL_REVERTED");
    }
}
