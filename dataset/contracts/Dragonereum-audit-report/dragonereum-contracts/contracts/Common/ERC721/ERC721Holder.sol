pragma solidity 0.4.25;

import "./ERC721Receiver.sol";

contract ERC721Holder is ERC721Receiver {
    function onERC721Received(address, address, uint256, bytes) public returns(bytes4) {
        return this.onERC721Received.selector;
    }
}
