// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

interface ICryptoPunksMarket {
    //to get address punk owner from mapping (uint => address) public punkIndexToAddress;
    function punkIndexToAddress(uint256 key) external returns (address);

    function buyPunk(uint256 punkIndex) external payable;

    function transferPunk(address to, uint256 punkIndex) external;

    function offerPunkForSaleToAddress(uint256 punkIndex, uint256 minSalePriceInWei, address toAddress) external;
}
