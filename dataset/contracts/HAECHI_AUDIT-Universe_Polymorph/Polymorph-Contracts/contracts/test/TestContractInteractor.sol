// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "./../IPolymorphWithGeneChanger.sol";

contract TestContractInteractor {

	IPolymorphWithGeneChanger public polymorphContract;

	constructor(address _polymorphAddress) public {
		polymorphContract = IPolymorphWithGeneChanger(_polymorphAddress);
	}

	function triggerGeneChange(uint256 tokenId, uint256 genePosition) payable public {
		polymorphContract.morphGene{value: msg.value}(tokenId, genePosition);
	}

	function triggerRandomize(uint256 tokenId) payable public {
		polymorphContract.randomizeGenome{value: msg.value}(tokenId);
	}
}