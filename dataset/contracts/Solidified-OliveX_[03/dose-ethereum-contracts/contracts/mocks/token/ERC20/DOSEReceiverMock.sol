// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import "@animoca/ethereum-contracts-assets/contracts/mocks/token/ERC20/ERC20ReceiverMock.sol";

contract DOSEReceiverMock is ERC20ReceiverMock {
    constructor(bool accept, address tokenAddress) ERC20ReceiverMock(accept, tokenAddress) {}
}
