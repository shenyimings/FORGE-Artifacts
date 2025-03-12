// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;



interface IMaArtProxy {
    function _tokenURI(uint _tokenId) external pure returns (string memory output);
}
