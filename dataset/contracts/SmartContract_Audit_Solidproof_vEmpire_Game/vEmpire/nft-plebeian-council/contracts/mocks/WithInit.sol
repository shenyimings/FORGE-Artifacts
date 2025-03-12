// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity >=0.6 <0.9;
pragma experimental ABIEncoderV2;

import "./ERC721ReceiverMockUpgradeable.sol";

contract ERC721ReceiverMockUpgradeableWithInit is
    ERC721ReceiverMockUpgradeable
{
    constructor(bytes4 retval, Error error) public payable {
        __ERC721ReceiverMock_init(retval, error);
    }
}
