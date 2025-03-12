/* SPDX-License-Identifier: MIT */

pragma solidity ^0.8.0;

import "./tokens/ERC721/GameNFT721.sol";
import "./tokens/ERC1155/GameNFT1155.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SuperfineNFTBurning is Ownable {
    mapping(address => bool) private _operators;

    event Erc721BurnedIntoGames(
        address indexed owner,
        address indexed nftAddress,
        uint256 indexed tokenId
    );
    event Erc1155BurnedIntoGames(
        address indexed owner,
        address indexed nftAddress,
        uint256[] tokenIds,
        uint256[] quantities
    );

    constructor() {
        _operators[msg.sender] = true;
    }

    modifier onlyOperators() {
        require(
            _operators[msg.sender],
            "SuperfineNFTBurning: caller is not operator"
        );
        _;
    }

    function setOperators(
        address[] memory operators,
        bool[] memory isOperators
    ) external onlyOwner {
        require(
            operators.length == isOperators.length,
            "SuperfineNFTBurning: lengths mismatch"
        );
        for (uint256 i = 0; i < operators.length; i++)
            _operators[operators[i]] = isOperators[i];
    }

    function burnErc721IntoGames(
        address[] memory nftAddresses,
        uint256[] memory tokenIds
    ) external onlyOperators {
        require(
            nftAddresses.length == tokenIds.length,
            "SuperfineNFTBurning: lengths mismatch"
        );
        for (uint256 i = 0; i < nftAddresses.length; i++) {
            bool success = ERC165Checker.supportsERC165(nftAddresses[i]);
            if (success)
                success = IERC165(nftAddresses[i]).supportsInterface(
                    type(IERC721).interfaceId
                );
            require(success, "SuperfineNFTBurning: invalid ERC721 address");
            GameNFT721 nftContract = GameNFT721(nftAddresses[i]);
            address currentOwner = nftContract.ownerOf(tokenIds[i]);
            nftContract.burn(tokenIds[i]);
            emit Erc721BurnedIntoGames(
                currentOwner,
                nftAddresses[i],
                tokenIds[i]
            );
        }
    }

    function burnErc1155IntoGames(
        address[] memory owners,
        address[] memory nftAddresses,
        uint256[][] memory tokenIds,
        uint256[][] memory quantities
    ) external onlyOperators {
        require(
            owners.length == nftAddresses.length &&
                owners.length == tokenIds.length &&
                owners.length == quantities.length,
            "SuperfineNFTBurning: lengths mismatch"
        );
        for (uint256 i = 0; i < owners.length; i++) {
            bool success = ERC165Checker.supportsERC165(nftAddresses[i]);
            if (success)
                success = IERC165(nftAddresses[i]).supportsInterface(
                    type(IERC1155).interfaceId
                );
            require(success, "SuperfineNFTBurning: invalid ERC1155 address");
            GameNFT1155(nftAddresses[i]).burnBatch(
                owners[i],
                tokenIds[i],
                quantities[i]
            );
            emit Erc1155BurnedIntoGames(
                owners[i],
                nftAddresses[i],
                tokenIds[i],
                quantities[i]
            );
        }
    }
}
