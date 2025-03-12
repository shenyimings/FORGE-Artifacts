// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./PolymorphGeneGenerator.sol";
import "./Polymorph.sol";
import "./IPolymorphWithGeneChanger.sol";


contract PolymorphWithGeneChanger is IPolymorphWithGeneChanger, Polymorph {
    using PolymorphGeneGenerator for PolymorphGeneGenerator.Gene;
    using SafeMath for uint256;
    using Address for address;

    mapping(uint256 => uint256) internal _genomeChanges;
    uint256 public baseGenomeChangePrice;
    uint256 public randomizeGenomePrice;

    event BaseGenomeChangePriceChanged(uint256 newGenomeChange);
    event RandomizeGenomePriceChanged(uint256 newRandomizeGenomePriceChange);

    constructor(string memory name, string memory symbol, string memory baseURI, address payable _daoAddress, uint premintedTokensCount, uint256 _baseGenomeChangePrice, uint256 _polymorphPrice, uint256 totalSupply, uint256 _randomizeGenomePrice, uint256 _bulkBuyLimit, string memory _arweaveAssetsJSON) Polymorph(name, symbol, baseURI, _daoAddress, premintedTokensCount, _polymorphPrice, totalSupply, _bulkBuyLimit, _arweaveAssetsJSON) {
        baseGenomeChangePrice = _baseGenomeChangePrice;
        randomizeGenomePrice = _randomizeGenomePrice;
    }

    function changeBaseGenomeChangePrice(uint256 newGenomeChangePrice)  public override virtual onlyDAO {
        baseGenomeChangePrice = newGenomeChangePrice;
        emit BaseGenomeChangePriceChanged(newGenomeChangePrice);
    }

    function changeRandomizeGenomePrice(uint256 newRandomizeGenomePrice)  public override virtual onlyDAO {
        randomizeGenomePrice = newRandomizeGenomePrice;
        emit RandomizeGenomePriceChanged(newRandomizeGenomePrice);
    }

    function morphGene(uint256 tokenId, uint256 genePosition) public payable virtual override nonReentrant {
        require(genePosition > 0, "Base character not morphable");
        _beforeGenomeChange(tokenId);
        uint256 price = priceForGenomeChange(tokenId);
        
        (bool transferToDaoStatus, ) = daoAddress.call{value:price}("");
        require(transferToDaoStatus, "Address: unable to send value, recipient may have reverted");

        uint256 excessAmount = msg.value.sub(price);
        if (excessAmount > 0) {
            (bool returnExcessStatus, ) = _msgSender().call{value: excessAmount}("");
            require(returnExcessStatus, "Failed to return excess.");
        }

        uint256 oldGene = _genes[tokenId];
        uint256 newTrait = geneGenerator.random()%100;
        _genes[tokenId] = replaceGene(oldGene, newTrait, genePosition);
        _genomeChanges[tokenId]++;
        emit TokenMorphed(tokenId, oldGene, oldGene, price, PolymorphEventType.MORPH);
    }

    function replaceGene(uint256 genome, uint256 replacement, uint256 genePosition) internal virtual pure returns(uint256 newGene) {
        require(genePosition < 38, "Bad gene position");
        uint256 mod = 0;
        if (genePosition > 0) {
            mod = genome.mod(10**(genePosition * 2)); // Each gene is 2 digits long
        }
        uint256 div = genome.div(10 ** ((genePosition + 1) * 2)).mul(10 ** ((genePosition + 1) * 2));
        uint256 insert = replacement * (10 ** (genePosition * 2));
        newGene = div.add(insert).add(mod);
        return newGene;
    }

    function randomizeGenome(uint256 tokenId) public payable override virtual nonReentrant {
        _beforeGenomeChange(tokenId);

        (bool transferToDaoStatus, ) = daoAddress.call{value:randomizeGenomePrice}("");
        require(transferToDaoStatus, "Address: unable to send value, recipient may have reverted");

        uint256 excessAmount = msg.value.sub(randomizeGenomePrice);
        if (excessAmount > 0) {
            (bool returnExcessStatus, ) = _msgSender().call{value: excessAmount}("");
            require(returnExcessStatus, "Failed to return excess.");
        }
        
        uint256 oldGene = _genes[tokenId];
        _genes[tokenId] = geneGenerator.random();
        _genomeChanges[tokenId] = 0;
        emit TokenMorphed(tokenId, oldGene, _genes[tokenId], randomizeGenomePrice, PolymorphEventType.MORPH);
    }

    function priceForGenomeChange(uint256 tokenId) public override virtual view returns(uint256 price) {
        uint256 pastChanges = _genomeChanges[tokenId];

        return baseGenomeChangePrice.mul(1 << pastChanges);
    }

    function _beforeGenomeChange(uint256 tokenId) internal virtual {
        require(!address(_msgSender()).isContract(), "Caller cannot be a contract");
        require(ownerOf(tokenId) == _msgSender(), "PolymorphWithGeneChanger: cannot change genome of token that is not own");
    }
    
}
