// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Sender.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract ReentrancyChecker is
    IERC1155Receiver,
    IERC777Recipient,
    IERC777Sender,
    IERC721Receiver
{
    struct ExecParams {
        address to;
        bytes payload;
        uint256 value;
        uint256 count;
        uint256 countSuccess;
    }

    ExecParams params;
    uint256 maxRecursion = 2;

    function execute(address to, bytes calldata payload)
        public
        payable
        returns (bool success, bytes memory data)
    {
        params.to = to;
        params.payload = payload;
        params.value = msg.value;
        params.count = 0;
        params.countSuccess = 0;

        (success, data) = to.call{value: msg.value}(payload);

        if (!success) {
            revert(string(abi.encodePacked(data)));
        }

        if (params.countSuccess > 0) {
            revert("Reentrancy detected!");
        }
    }

    function reenter() internal {
        if (params.count < maxRecursion) {
            params.count += 1;
            (bool success, bytes memory data) = params.to.call{
                value: params.value
            }(params.payload);
            require(success, string(abi.encodePacked(data)));
            params.countSuccess += 1;
        }
    }

    // ERC1155

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        reenter();

        return
            bytes4(
                keccak256(
                    "onERC1155Received(address,address,uint256,uint256,bytes)"
                )
            );
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        reenter();

        return
            bytes4(
                keccak256(
                    "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
                )
            );
    }

    // ERC777

    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external override {
        reenter();
    }

    function tokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external override {
        reenter();
    }

    // ERC721

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        reenter();

        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }

    function supportsInterface(bytes4 interfaceId)
        external
        view
        override
        returns (bool)
    {
        return true;
    }
}
