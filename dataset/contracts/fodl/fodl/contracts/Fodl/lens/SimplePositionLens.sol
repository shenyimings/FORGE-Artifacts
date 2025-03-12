// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import '../connectors/interfaces/ISimplePositionBaseConnector.sol';
import '../core/FoldingRegistry.sol';

contract SimplePositionLens {
    function getPositionsMetadata(address[] calldata positions)
        external
        returns (SimplePositionMetadata[] memory assetsData)
    {
        assetsData = new SimplePositionMetadata[](positions.length);

        for (uint256 i = 0; i < positions.length; i++) {
            assetsData[i] = ISimplePositionBaseConnector(positions[i]).getPositionMetadata();
        }
    }

    function getAllMyPositionsFromNFT(address foldingNFT)
        external
        returns (SimplePositionMetadata[] memory assetsData)
    {
        uint256 numberOfPositions = ERC721(foldingNFT).balanceOf(msg.sender);
        assetsData = new SimplePositionMetadata[](numberOfPositions);

        for (uint256 i = 0; i < numberOfPositions; i++) {
            assetsData[i] = ISimplePositionBaseConnector(ERC721(foldingNFT).tokenOfOwnerByIndex(msg.sender, i))
                .getPositionMetadata();
        }
    }
}
