// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract MockERC721Receiver is IERC721Receiver {
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) external pure returns (bytes4) {
        _operator;
        _from;
        _tokenId;
        if (_data.length > 0) {
            bytes32 payload = abi.decode(_data, (bytes32));
            if (payload == bytes32("return wrong")) {
                return bytes4(0x11111111);
            } else if (payload == bytes32("custom error")) {
                revert("Custom Error");
            }
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}
