// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TestERC1155 is ERC1155 {
    address public owner;

    constructor() ERC1155("http://test.com/uri") {
        owner = msg.sender;
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        string memory data
    ) public {
        _mint(account, id, amount, bytes(data));
    }
}
