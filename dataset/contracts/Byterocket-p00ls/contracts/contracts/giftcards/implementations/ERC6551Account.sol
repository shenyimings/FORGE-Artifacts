// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/interfaces/IERC5313.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";

import "../interfaces/IERC6551Account.sol";
import "../interfaces/IERC6551Executable.sol";

contract ERC6551Account is
    IERC165,
    IERC1271,
    IERC5313,
    IERC6551Account,
    IERC6551Executable,
    ERC721Holder,
    ERC1155Holder,
    Multicall
{
    // IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC1155Receiver) returns (bool) {
        return super.supportsInterface(interfaceId)
            || interfaceId == type(IERC6551Account).interfaceId
            || interfaceId == type(IERC6551Executable).interfaceId;
    }

    // IERC1271
    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        virtual
        returns (bytes4 magicValue)
    {
        return SignatureChecker.isValidSignatureNow(owner(), hash, signature)
            ? IERC1271.isValidSignature.selector
            : bytes4(0);
    }

    // IERC5313
    function owner() public view virtual returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = token();
        if (chainId != block.chainid) return address(0);

        return IERC721(tokenContract).ownerOf(tokenId);
    }

    // IERC6551Account
    uint256 public state;

    receive() external payable {}

    function token() public view virtual returns (uint256, address, uint256) {
        bytes memory footer = new bytes(0x60);

        assembly {
            extcodecopy(address(), add(footer, 0x20), 0x4d, 0x60)
        }

        return abi.decode(footer, (uint256, address, uint256));
    }

    function isValidSigner(address signer, bytes calldata) external view virtual returns (bytes4) {
        return signer == owner()
            ? IERC6551Account.isValidSigner.selector
            : bytes4(0);
    }

    // IERC6551Executable
    function execute(address to, uint256 value, bytes calldata data, uint8 operation)
        external
        payable
        virtual
        returns (bytes memory result)
    {
        require(msg.sender == owner(), "Invalid signer");
        require(operation == 0, "Only call operations are supported");

        ++state;

        (bool success, bytes memory returndata) = to.call{value: value}(data);
        return Address.verifyCallResult(success, returndata, 'ERC6551Account execution failed');
    }
}
