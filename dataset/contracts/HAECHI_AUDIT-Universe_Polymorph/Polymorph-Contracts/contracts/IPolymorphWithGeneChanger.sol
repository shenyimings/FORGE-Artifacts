// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "./IPolymorph.sol";


interface IPolymorphWithGeneChanger is IPolymorph {

    function morphGene(uint256 tokenId, uint256 genePosition) external payable;
    function randomizeGenome(uint256 tokenId) external payable virtual;
    function priceForGenomeChange(uint256 tokenId) external virtual view returns(uint256 price);
    function changeBaseGenomeChangePrice(uint256 newGenomeChangePrice) external virtual;
    function changeRandomizeGenomePrice(uint256 newRandomizeGenomePrice) external virtual;

}