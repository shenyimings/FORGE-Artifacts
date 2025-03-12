// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

contract Metadata {
    struct TokenMetadata {
        bool isAdded;
        address routerAddress;
        string imageUrl;
    }

    mapping(address => TokenMetadata) public tokenMeta;

    function updateMeta(
        address _tokenAddress,
        address _routerAddress,
        string memory _imageUrl
    ) internal {
        if (_tokenAddress != address(0)) {
            tokenMeta[_tokenAddress] = TokenMetadata({
                isAdded: true,
                routerAddress: _routerAddress,
                imageUrl: _imageUrl
            });
        }
    }

    function updateMetaURL(address _tokenAddress, string memory _imageUrl)
        internal
    {
        TokenMetadata storage meta = tokenMeta[_tokenAddress];
        require(meta.isAdded, "Invalid token address");

        meta.imageUrl = _imageUrl;
    }
}
