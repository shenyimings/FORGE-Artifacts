// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "./LibShare.sol";
import "../TokenERC721.sol";
import "../PNDC_ERC721.sol";

library LibRoyalty {
    function retrieveRoyalty(
        address _collectionAddress,
        address _pndcAddress,
        uint256 _tokenId
    ) public view returns (LibShare.Share[] memory) {
        if (_collectionAddress == _pndcAddress) {
            return PNDC_ERC721(_pndcAddress).getRoyalties(_tokenId);
        } else {
            return TokenERC721(_collectionAddress).getRoyalties(_tokenId);
        }
    }
}
