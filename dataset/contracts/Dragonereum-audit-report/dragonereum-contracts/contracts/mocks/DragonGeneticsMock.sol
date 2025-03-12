pragma solidity 0.4.25;


import "../Dragon/DragonGenetics.sol";

contract DragonGeneticsMock is DragonGenetics {

    function getWeightedRandom(uint256 _random) public view returns (uint8) {
        return _getWeightedRandom(_random);
    }

    function generateGen(uint8 _dragonType, uint256 _random) public view returns (uint8[16]) {
        return _generateGen(_dragonType, _random);
    }

    function getSpecialRandom(
        uint256 _seed_,
        uint8 _digits
    ) public pure returns (uint256, uint256) {
        return _getSpecialRandom(_seed_, _digits);
    }

    function testComposed(uint256[4] _composed) public pure returns (uint256[4]){
        uint8[16][10] memory decomposed = _parseGenome(_composed);
        return _composeGenome(decomposed);
    }

    function calculateGen(
        uint8[16] _momGen,
        uint8[16] _dadGen,
        uint8 _random
    ) external pure returns (uint8[16] gen) {
        gen = _calculateGen(_momGen, _dadGen, _random);
    }

    function mutateGene(uint8[16] _gene, uint8 _genType) public pure returns (uint8[16]) {
        return _mutateGene(_gene, _genType);
    }

    function calculateDragonTypes(uint256[4] _composed) public pure returns (uint8[11] dragonTypesArray) {
        uint8[16][10] memory _genome = _parseGenome(_composed);
        return _calculateDragonTypes(_genome);

    }
    function checkInbreeding(uint256[2] _parents) external view returns (uint8 chance) {
        return _checkInbreeding(_parents);
    }

}
