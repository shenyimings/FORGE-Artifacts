pragma solidity 0.4.25;

import "../Dragon/DragonUtils.sol";

contract DragonUtilsMock is DragonUtils {


    function getActiveGene(uint8[16] _gene) public pure returns (uint8[3] gene) {
        return _getActiveGene(_gene);
    }

    function getActiveGeneIndex(uint8[16] _gene) public pure returns (uint8) {
        return _getActiveGeneIndex(_gene);
    }

    function getActiveGenes(uint8[16][10] _genome) public pure returns (uint8[30] genome) {
        return _getActiveGenes(_genome);
    }

    function getIndexAndFactor(uint8 _counter) public pure returns (uint8 index, uint8 factor) {
        return _getIndexAndFactor(_counter);
    }

    function parseGenome(uint256[4] _composed) public pure returns (uint8[16][10]) {
        return _parseGenome(_composed);
    }

    function composeGenome(uint8[16][10] _parsed) public pure returns (uint256[4] composed) {
        return _composeGenome(_parsed);
    }
}
