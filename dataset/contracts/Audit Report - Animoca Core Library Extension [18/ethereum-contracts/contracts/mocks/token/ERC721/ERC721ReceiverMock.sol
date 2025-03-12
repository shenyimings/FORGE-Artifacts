// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC721Receiver} from "./../../../token/ERC721/interfaces/IERC721Receiver.sol";
import {ERC721Storage} from "./../../../token/ERC721/libraries/ERC721Storage.sol";
import {ERC721Receiver} from "./../../../token/ERC721/ERC721Receiver.sol";

/// @title ERC721 Receiver Mock
contract ERC721ReceiverMock is ERC721Receiver {
    bool internal immutable _ACCEPT_721;
    address internal immutable _TOKEN_ADDRESS_721;

    event ERC721Received(address operator, address from, uint256 tokenId, bytes data);

    error WrongToken();

    constructor(bool accept721, address tokenAddress) ERC721Receiver() {
        _ACCEPT_721 = accept721;
        _TOKEN_ADDRESS_721 = tokenAddress;
    }

    //=================================================== ERC721Receiver ====================================================//

    /// @inheritdoc IERC721Receiver
    /// @dev reverts if the sender is not the supported ERC721 contract.
    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data) public virtual override returns (bytes4) {
        if (msg.sender != _TOKEN_ADDRESS_721) revert WrongToken();
        if (_ACCEPT_721) {
            emit ERC721Received(operator, from, tokenId, data);
            return ERC721Storage.ERC721_RECEIVED;
        } else {
            return 0x0;
        }
    }
}
