pragma solidity 0.4.25;


import "../Common/Upgradable.sol";
import "./DragonUtils.sol";
import "../Getter.sol";
import "../Common/SafeMath16.sol";

contract DragonGenetics is Upgradable, DragonUtils {
    using SafeMath16 for uint16;
    using SafeMath256 for uint256;

    Getter getter;

    uint8 constant MUTATION_CHANCE = 1; // 10%
    uint16[7] genesWeights = [300, 240, 220, 190, 25, 15, 10];

    // choose pair
    function _chooseGen(uint8 _random, uint8[16] _array1, uint8[16] _array2) internal pure returns (uint8[16] gen) {
        uint8 x = _random.div(2);
        uint8 y = _random % 2;
        for (uint8 j = 0; j < 2; j++) {
            for (uint8 k = 0; k < 4; k++) {
                gen[k.add(j.mul(8))] = _array1[k.add(j.mul(4)).add(x.mul(8))];
                gen[k.add(j.mul(2).add(1).mul(4))] = _array2[k.add(j.mul(4)).add(y.mul(8))];
            }
        }
    }

    function _getParents(uint256 _id) internal view returns (uint256[2]) {
        if (_id != 0) {
            return getter.getDragonParents(_id);
        }
        return [uint256(0), uint256(0)];
    }

    function _checkInbreeding(uint256[2] memory _parents) internal view returns (uint8 chance) {
        uint8 _relatives;
        uint8 i;
        uint256[2] memory _parents_1_1 = _getParents(_parents[0]);
        uint256[2] memory _parents_1_2 = _getParents(_parents[1]);
        // check grandparents
        if (_parents_1_1[0] != 0 && (_parents_1_1[0] == _parents_1_2[0] || _parents_1_1[0] == _parents_1_2[1])) {
            _relatives = _relatives.add(1);
        }
        if (_parents_1_1[1] != 0 && (_parents_1_1[1] == _parents_1_2[0] || _parents_1_1[1] == _parents_1_2[1])) {
            _relatives = _relatives.add(1);
        }
        // check parents and grandparents
        if (_parents[0] == _parents_1_2[0] || _parents[0] == _parents_1_2[1]) {
            _relatives = _relatives.add(1);
        }
        if (_parents[1] == _parents_1_1[0] || _parents[1] == _parents_1_1[1]) {
            _relatives = _relatives.add(1);
        }
        if (_relatives >= 2) return 8; // 80% chance of a bad mutation
        if (_relatives == 1) chance = 7; // 70% chance
        // check grandparents and great-grandparents
        uint256[12] memory _ancestors;
        uint256[2] memory _parents_2_1 = _getParents(_parents_1_1[0]);
        uint256[2] memory _parents_2_2 = _getParents(_parents_1_1[1]);
        uint256[2] memory _parents_2_3 = _getParents(_parents_1_2[0]);
        uint256[2] memory _parents_2_4 = _getParents(_parents_1_2[1]);
        for (i = 0; i < 2; i++) {
            _ancestors[i.mul(6).add(0)] = _parents_1_1[i];
            _ancestors[i.mul(6).add(1)] = _parents_1_2[i];
            _ancestors[i.mul(6).add(2)] = _parents_2_1[i];
            _ancestors[i.mul(6).add(3)] = _parents_2_2[i];
            _ancestors[i.mul(6).add(4)] = _parents_2_3[i];
            _ancestors[i.mul(6).add(5)] = _parents_2_4[i];
        }
        for (i = 0; i < 12; i++) {
            for (uint8 j = i.add(1); j < 12; j++) {
                if (_ancestors[i] != 0 && _ancestors[i] == _ancestors[j]) {
                    _relatives = _relatives.add(1);
                    _ancestors[j] = 0;
                }
                if (_relatives > 2 || (_relatives == 2 && chance == 0)) return 8; // 80% chance
            }
        }
        if (_relatives == 1 && chance == 0) return 5; // 50% chance
    }

    function _mutateGene(uint8[16] _gene, uint8 _genType) internal pure returns (uint8[16]) {
        uint8 _index = _getActiveGeneIndex(_gene);
        _gene[_index.mul(4).add(1)] = _genType; // new gene type
        _gene[_index.mul(4).add(2)] = 1; // reset level
        return _gene;
    }

    // select one of 16 variations
    function _calculateGen(
        uint8[16] _momGen,
        uint8[16] _dadGen,
        uint8 _random
    ) internal pure returns (uint8[16] gen) {
        if (_random < 4) {
            return _chooseGen(_random, _momGen, _momGen);
        } else if (_random < 8) {
            return _chooseGen(_random.sub(4), _momGen, _dadGen);
        } else if (_random < 12) {
            return _chooseGen(_random.sub(8), _dadGen, _dadGen);
        } else {
            return _chooseGen(_random.sub(12), _dadGen, _momGen);
        }
    }

    function _calculateGenome(
        uint8[16][10] memory _momGenome,
        uint8[16][10] memory _dadGenome,
        uint8 _uglinessChance,
        uint256 _seed_
    ) internal pure returns (uint8[16][10] genome) {
        uint256 _seed = _seed_;
        uint256 _random;
        uint8 _mutationChance = _uglinessChance == 0 ? MUTATION_CHANCE : _uglinessChance;
        uint8 _geneType;
        for (uint8 i = 0; i < 10; i++) {
            (_random, _seed) = _getSpecialRandom(_seed, 4);
            genome[i] = _calculateGen(_momGenome[i], _dadGenome[i], (_random % 16).toUint8());
            (_random, _seed) = _getSpecialRandom(_seed, 1);
            if (_random < _mutationChance) {
                _geneType = 0;
                if (_uglinessChance == 0) {
                    (_random, _seed) = _getSpecialRandom(_seed, 2);
                    _geneType = (_random % 9).add(1).toUint8(); // [1..9]
                }
                genome[i] = _mutateGene(genome[i], _geneType);
            }
        }
    }

    // 40 points in sum
    function _calculateDragonTypes(uint8[16][10] _genome) internal pure returns (uint8[11] dragonTypesArray) {
        uint8 _dragonType;
        for (uint8 i = 0; i < 10; i++) {
            for (uint8 j = 0; j < 4; j++) {
                _dragonType = _genome[i][j.mul(4)];
                dragonTypesArray[_dragonType] = dragonTypesArray[_dragonType].add(1);
            }
        }
    }

    function createGenome(
        uint256[2] _parents,
        uint256[4] _momGenome,
        uint256[4] _dadGenome,
        uint256 _seed
    ) external view returns (
        uint256[4] genome,
        uint8[11] dragonTypes
    ) {
        uint8 _uglinessChance = _checkInbreeding(_parents);
        uint8[16][10] memory _parsedGenome = _calculateGenome(
            _parseGenome(_momGenome),
            _parseGenome(_dadGenome),
            _uglinessChance,
            _seed
        );
        genome = _composeGenome(_parsedGenome);
        dragonTypes = _calculateDragonTypes(_parsedGenome);
    }

    function _getWeightedRandom(uint256 _random) internal view returns (uint8) {
        uint16 _weight;
        for (uint8 i = 1; i < 7; i++) {
            _weight = _weight.add(genesWeights[i.sub(1)]);
            if (_random < _weight) return i;
        }
        return 7;
    }

    function _generateGen(uint8 _dragonType, uint256 _random) internal view returns (uint8[16]) {
        uint8 _geneType = _getWeightedRandom(_random); // [1..7]
        return [
            _dragonType, _geneType, 1, 1,
            _dragonType, _geneType, 1, 0,
            _dragonType, _geneType, 1, 0,
            _dragonType, _geneType, 1, 0
        ];
    }

    // max 4 digits
    function _getSpecialRandom(
        uint256 _seed_,
        uint8 _digits
    ) internal pure returns (uint256, uint256) {
        uint256 _base = 10;
        uint256 _seed = _seed_;
        uint256 _random = _seed % _base.pow(_digits);
        _seed = _seed.div(_base.pow(_digits));
        return (_random, _seed);
    }

    function createGenomeForGenesis(uint8 _dragonType, uint256 _seed_) external view returns (uint256[4]) {
        uint256 _seed = _seed_;
        uint8[16][10] memory _genome;
        uint256 _random;
        for (uint8 i = 0; i < 10; i++) {
            (_random, _seed) = _getSpecialRandom(_seed, 3);
            _genome[i] = _generateGen(_dragonType, _random);
        }
        return _composeGenome(_genome);
    }

    function setInternalDependencies(address[] _newDependencies) public onlyOwner {
        super.setInternalDependencies(_newDependencies);

        getter = Getter(_newDependencies[0]);
    }
}
