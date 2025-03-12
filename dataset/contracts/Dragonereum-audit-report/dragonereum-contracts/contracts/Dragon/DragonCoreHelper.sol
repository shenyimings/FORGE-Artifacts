pragma solidity 0.4.25;


import "./DragonUtils.sol";
import "./DragonParams.sol";
import "../Common/Name.sol";
import "../Common/Upgradable.sol";
import "../Common/SafeMath16.sol";
import "../Common/SafeMath32.sol";
import "../Common/SafeMath256.sol";
import "../Common/SafeConvert.sol";

/* solium-disable operator-whitespace */
/* solium-disable security/no-inline-assembly */

contract DragonCoreHelper is Upgradable, DragonUtils, Name {
    using SafeMath16 for uint16;
    using SafeMath32 for uint32;
    using SafeMath256 for uint256;
    using SafeConvert for uint32;
    using SafeConvert for uint256;

    DragonParams params;

    uint8 constant PERCENT_MULTIPLIER = 100;
    uint8 constant MAX_PERCENTAGE = 100;

    uint8 constant MAX_GENE_LVL = 99;

    uint8 constant MAX_LEVEL = 10;

    function _min(uint32 lth, uint32 rth) internal pure returns (uint32) {
        return lth > rth ? rth : lth;
    }

    function _calculateSkillWithBuff(uint32 _skill, uint32 _buff) internal pure returns (uint32) {
        return _buff > 0 ? _skill.mul(_buff).div(100) : _skill; // buff is multiplied by 100
    }

    function _calculateRegenerationSpeed(uint32 _max) internal pure returns (uint32) {
        // because HP/mana is multiplied by 100 so we need to have step multiplied by 100 too
        return _sqrt(_max.mul(100)).div(2).div(1 minutes); // hp/mana in second
    }

    function calculateFullRegenerationTime(uint32 _max) external pure returns (uint32) { // in seconds
        return _max.div(_calculateRegenerationSpeed(_max));
    }

    function calculateCurrent(
        uint256 _pastTime,
        uint32 _max,
        uint32 _remaining
    ) external pure returns (
        uint32 current,
        uint8 percentage
    ) {
        if (_remaining >= _max) {
            return (_max, MAX_PERCENTAGE);
        }
        uint32 _speed = _calculateRegenerationSpeed(_max); // points per second
        uint32 _secondsToFull = _max.sub(_remaining).div(_speed); // seconds to full
        uint32 _secondsPassed = _pastTime.toUint32(); // seconds that already passed
        if (_secondsPassed >= _secondsToFull.add(1)) {
            return (_max, MAX_PERCENTAGE); // return full if passed more or equal to needed
        }
        current = _min(_max, _remaining.add(_speed.mul(_secondsPassed)));
        percentage = _min(MAX_PERCENTAGE, current.mul(PERCENT_MULTIPLIER).div(_max)).toUint8();
    }

    function calculateHealthAndMana(
        uint32 _initStamina,
        uint32 _initIntelligence,
        uint32 _staminaBuff,
        uint32 _intelligenceBuff
    ) external pure returns (uint32 health, uint32 mana) {
        uint32 _stamina = _initStamina;
        uint32 _intelligence = _initIntelligence;

        _stamina = _calculateSkillWithBuff(_stamina, _staminaBuff);
        _intelligence = _calculateSkillWithBuff(_intelligence, _intelligenceBuff);

        health = _stamina.mul(5);
        mana = _intelligence.mul(5);
    }

    function _sqrt(uint32 x) internal pure returns (uint32 y) {
        uint32 z = x.add(1).div(2);
        y = x;
        while (z < y) {
            y = z;
            z = x.div(z).add(z).div(2);
        }
    }

    // _dragonTypes[i] in [0..39] range, sum of all _dragonTypes items = 40 (number of genes)
    // _random in [0..39] range
    function getSpecialBattleSkillDragonType(uint8[11] _dragonTypes, uint256 _random) external pure returns (uint8 skillDragonType) {
        uint256 _currentChance;
        for (uint8 i = 0; i < 11; i++) {
            _currentChance = _currentChance.add(_dragonTypes[i]);
            if (_random < _currentChance) {
                skillDragonType = i;
                break;
            }
        }
    }

    function _getBaseSkillIndex(uint8 _dragonType) internal pure returns (uint8) {
        // 2 - stamina
        // 0 - attack
        // 3 - speed
        // 1 - defense
        // 4 - intelligence
        uint8[5] memory _skills = [2, 0, 3, 1, 4];
        return _skills[_dragonType];
    }

    function calculateSpecialBattleSkill(
        uint8 _dragonType,
        uint32[5] _skills
    ) external pure returns (
        uint32 cost,
        uint8 factor,
        uint8 chance
    ) {
        uint32 _baseSkill = _skills[_getBaseSkillIndex(_dragonType)];
        uint32 _intelligence = _skills[4];

        cost = _baseSkill.mul(3);
        factor = _sqrt(_baseSkill.div(3)).add(10).toUint8(); // factor is increased by 10
        // skill is multiplied by 100 so we divide the result by sqrt(100) = 10
        chance = _sqrt(_intelligence).div(10).add(10).toUint8();
    }

    function _getSkillIndexBySpecialPeacefulSkillClass(
        uint8 _class
    ) internal pure returns (uint8) {
        // 0 - attack
        // 1 - defense
        // 2 - stamina
        // 3 - speed
        // 4 - intelligence
        uint8[8] memory _buffsIndexes = [0, 0, 1, 2, 3, 4, 2, 4]; // 0 item - no such class
        return _buffsIndexes[_class];
    }

    function calculateSpecialPeacefulSkill(
        uint8 _class,
        uint32[5] _skills,
        uint32[5] _buffs
    ) external pure returns (uint32 cost, uint32 effect) {
        uint32 _index = _getSkillIndexBySpecialPeacefulSkillClass(_class);
        uint32 _skill = _calculateSkillWithBuff(_skills[_index], _buffs[_index]);
        if (_class == 6 || _class == 7) { // healing or mana recharge
            effect = _skill.mul(2);
        } else {
            // sqrt(skill / 30) + 1
            effect = _sqrt(_skill.mul(10).div(3)).add(100); // effect is increased by 100 as skills
        }
        cost = _skill.mul(3);
    }

    function _getGeneVarietyFactor(uint8 _type) internal pure returns (uint32 value) {
        // multiplied by 10
        if (_type == 0) value = 5;
        else if (_type < 5) value = 12;
        else if (_type < 8) value = 16;
        else value = 28;
    }

    function calculateCoolness(uint256[4] _composedGenome) external pure returns (uint32 coolness) {
        uint8[16][10] memory _genome = _parseGenome(_composedGenome);
        uint32 _geneVarietyFactor; // multiplied by 10
        uint8 _strengthCoefficient; // multiplied by 10
        uint8 _geneLevel;
        for (uint8 i = 0; i < 10; i++) {
            for (uint8 j = 0; j < 4; j++) {
                _geneVarietyFactor = _getGeneVarietyFactor(_genome[i][(j * 4) + 1]);
                _strengthCoefficient = (_genome[i][(j * 4) + 3] == 0) ? 7 : 10; // recessive or dominant
                _geneLevel = _genome[i][(j * 4) + 2];
                coolness = coolness.add(_geneVarietyFactor.mul(_geneLevel).mul(_strengthCoefficient));
            }
        }
    }

    function calculateSkills(
        uint256[4] _composed
    ) external view returns (
        uint32, uint32, uint32, uint32, uint32
    ) {
        uint8[30] memory _activeGenes = _getActiveGenes(_parseGenome(_composed));
        uint8[5] memory _dragonTypeFactors;
        uint8[5] memory _bodyPartFactors;
        uint8[5] memory _geneTypeFactors;
        uint8 _level;
        uint32[5] memory _skills;

        for (uint8 i = 0; i < 10; i++) {
            _bodyPartFactors = params.bodyPartsFactors(i);
            _dragonTypeFactors = params.dragonTypesFactors(_activeGenes[i * 3]);
            _geneTypeFactors = params.geneTypesFactors(_activeGenes[i * 3 + 1]);
            _level = _activeGenes[i * 3 + 2];

            for (uint8 j = 0; j < 5; j++) {
                _skills[j] = _skills[j].add(uint32(_dragonTypeFactors[j]).mul(_bodyPartFactors[j]).mul(_geneTypeFactors[j]).mul(_level));
            }
        }
        return (_skills[0], _skills[1], _skills[2], _skills[3], _skills[4]);
    }

    function calculateExperience(
        uint8 _level,
        uint256 _experience,
        uint16 _dnaPoints,
        uint256 _factor
    ) external view returns (
        uint8 level,
        uint256 experience,
        uint16 dnaPoints
    ) {
        level = _level;
        experience = _experience;
        dnaPoints = _dnaPoints;

        uint8 _expToNextLvl;
        // _factor is multiplied by 10
        experience = experience.add(uint256(params.battlePoints()).mul(_factor).div(10));
        _expToNextLvl = params.experienceToNextLevel(level);
        while (experience >= _expToNextLvl && level < MAX_LEVEL) {
            experience = experience.sub(_expToNextLvl);
            level = level.add(1);
            dnaPoints = dnaPoints.add(params.dnaPoints(level));
            if (level < MAX_LEVEL) {
                _expToNextLvl = params.experienceToNextLevel(level);
            }
        }
    }

    function checkAndConvertName(string _input) external pure returns(bytes32, bytes32) {
        return _convertName(_input);
    }

    function _checkIfEnoughDNAPoints(bool _isEnough) internal pure {
        require(_isEnough, "not enough DNA points for upgrade");
    }

    function upgradeGenes(
        uint256[4] _composedGenome,
        uint16[10] _dnaPoints,
        uint16 _availableDNAPoints
    ) external view returns (
        uint256[4],
        uint16
    ) {
        uint16 _sum;
        uint8 _i;
        for (_i = 0; _i < 10; _i++) {
            _checkIfEnoughDNAPoints(_dnaPoints[_i] <= _availableDNAPoints);
            _sum = _sum.add(_dnaPoints[_i]);
        }
        _checkIfEnoughDNAPoints(_sum <= _availableDNAPoints);
        _sum = 0;

        uint8[16][10] memory _genome = _parseGenome(_composedGenome);
        uint8 _geneLevelIndex;
        uint8 _geneLevel;
        uint16 _geneUpgradeDNAPoints;
        uint8 _levelsToUpgrade;
        uint16 _specificDNAPoints;
        for (_i = 0; _i < 10; _i++) { // 10 active genes
            _specificDNAPoints = _dnaPoints[_i]; // points to upgrade current gene
            if (_specificDNAPoints > 0) {
                _geneLevelIndex = _getActiveGeneIndex(_genome[_i]).mul(4).add(2); // index of main gene level in genome
                _geneLevel = _genome[_i][_geneLevelIndex]; // current level of gene
                if (_geneLevel < MAX_GENE_LVL) {
                    // amount of points to upgrade to next level
                    _geneUpgradeDNAPoints = params.geneUpgradeDNAPoints(_geneLevel);
                    // while enough points and gene level is lower than max gene level
                    while (_specificDNAPoints >= _geneUpgradeDNAPoints && _geneLevel.add(_levelsToUpgrade) < MAX_GENE_LVL) {
                        _levelsToUpgrade = _levelsToUpgrade.add(1);
                        _specificDNAPoints = _specificDNAPoints.sub(_geneUpgradeDNAPoints);
                        _sum = _sum.add(_geneUpgradeDNAPoints); // the sum of used points
                        if (_geneLevel.add(_levelsToUpgrade) < MAX_GENE_LVL) {
                            _geneUpgradeDNAPoints = params.geneUpgradeDNAPoints(_geneLevel.add(_levelsToUpgrade));
                        }
                    }
                    _genome[_i][_geneLevelIndex] = _geneLevel.add(_levelsToUpgrade); // add levels to current gene
                    _levelsToUpgrade = 0;
                }
            }
        }
        return (_composeGenome(_genome), _sum);
    }

    function getActiveGenes(uint256[4] _composed) external pure returns (uint8[30]) {
        uint8[16][10] memory _genome = _parseGenome(_composed);
        return _getActiveGenes(_genome);
    }

    function setInternalDependencies(address[] _newDependencies) public onlyOwner {
        super.setInternalDependencies(_newDependencies);

        params = DragonParams(_newDependencies[0]);
    }
}
