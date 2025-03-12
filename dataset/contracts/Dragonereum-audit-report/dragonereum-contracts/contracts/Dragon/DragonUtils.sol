pragma solidity 0.4.25;

import "../Common/SafeMath8.sol";
import "../Common/SafeMath256.sol";
import "../Common/SafeConvert.sol";

contract DragonUtils {
    using SafeMath8 for uint8;
    using SafeMath256 for uint256;

    using SafeConvert for uint256;


    function _getActiveGene(uint8[16] _gene) internal pure returns (uint8[3] gene) {
        uint8 _index = _getActiveGeneIndex(_gene); // find active gene
        for (uint8 i = 0; i < 3; i++) {
            gene[i] = _gene[i + (_index * 4)]; // get all data for this gene
        }
    }

    function _getActiveGeneIndex(uint8[16] _gene) internal pure returns (uint8) {
        return _gene[3] >= _gene[7] ? 0 : 1;
    }

    // returns 10 active genes (one for each part of the body) with the next structure:
    // each gene is an array of 3 elements:
    // 0 - type of dragon
    // 1 - gene type
    // 2 - gene level
    function _getActiveGenes(uint8[16][10] _genome) internal pure returns (uint8[30] genome) {
        uint8[3] memory _activeGene;
        for (uint8 i = 0; i < 10; i++) {
            _activeGene = _getActiveGene(_genome[i]);
            genome[i * 3] = _activeGene[0];
            genome[i * 3 + 1] = _activeGene[1];
            genome[i * 3 + 2] = _activeGene[2];
        }
    }

    function _getIndexAndFactor(uint8 _counter) internal pure returns (uint8 index, uint8 factor) {
        if (_counter < 44) index = 0;
        else if (_counter < 88) index = 1;
        else if (_counter < 132) index = 2;
        else index = 3;
        factor = _counter.add(1) % 4 == 0 ? 10 : 100;
    }

    function _parseGenome(uint256[4] _composed) internal pure returns (uint8[16][10] parsed) {
        uint8 counter = 160; // 40 genes with 4 values in each one
        uint8 _factor;
        uint8 _index;

        for (uint8 i = 0; i < 10; i++) {
            for (uint8 j = 0; j < 16; j++) {
                counter = counter.sub(1);
                // _index - index of value in genome array where current gene is stored
                // _factor - denominator that determines the number of digits
                (_index, _factor) = _getIndexAndFactor(counter);
                parsed[9 - i][15 - j] = (_composed[_index] % _factor).toUint8();
                _composed[_index] /= _factor;
            }
        }
    }

    function _composeGenome(uint8[16][10] _parsed) internal pure returns (uint256[4] composed) {
        uint8 counter = 0;
        uint8 _index;
        uint8 _factor;

        for (uint8 i = 0; i < 10; i++) {
            for (uint8 j = 0; j < 16; j++) {
                (_index, _factor) = _getIndexAndFactor(counter);
                composed[_index] = composed[_index].mul(_factor);
                composed[_index] = composed[_index].add(_parsed[i][j]);
                counter = counter.add(1);
            }
        }
    }
}
