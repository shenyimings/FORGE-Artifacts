// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

interface IAirdrop {
    function claimRewards(uint256 tokenId, address to) external;
}

contract ApeCoinMock is ERC20, IAirdrop {
    address public immutable nftAddress;

    constructor(address _nftAddress) ERC20('Ape Coin', 'APE') {
        nftAddress = _nftAddress;
    }

    function claimRewards(uint256 tokenId, address to) external override {
        require(IERC721(nftAddress).ownerOf(tokenId) == _msgSender(), '');

        _mint(to, 10 ether);
    }
}