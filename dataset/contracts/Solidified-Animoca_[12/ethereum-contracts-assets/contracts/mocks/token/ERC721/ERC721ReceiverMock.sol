// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import {ERC721Receiver} from "../../../token/ERC721/ERC721Receiver.sol";

contract ERC721ReceiverMock is ERC721Receiver {
    event Received(address operator, address from, uint256 tokenId, bytes data, uint256 gas);

    bool internal _accept721;

    constructor(bool accept721) ERC721Receiver() {
        _accept721 = accept721;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes memory data
    ) public virtual override returns (bytes4) {
        if (_accept721) {
            emit Received(operator, from, tokenId, data, gasleft());
            return _ERC721_RECEIVED;
        } else {
            return _ERC721_REJECTED;
        }
    }
}
