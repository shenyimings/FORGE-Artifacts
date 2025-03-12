// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract CoinProxy is ERC1967Proxy {
    constructor(
        address implementation,
        address owner,
        bytes memory data
    ) ERC1967Proxy(implementation, data) {}
}
