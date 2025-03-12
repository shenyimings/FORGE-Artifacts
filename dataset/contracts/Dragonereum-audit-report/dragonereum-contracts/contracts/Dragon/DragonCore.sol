pragma solidity 0.4.25;

import "./DragonBase.sol";
import "../Common/SafeMath16.sol";

/* solium-disable operator-whitespace */

contract DragonCore is DragonBase {
    using SafeMath16 for uint16;

    uint8 constant MAX_LEVEL = 10; // max dragon level

    uint8 constant MAX_TACTICS_PERCENTAGE = 80;
    uint8 constant MIN_TACTICS_PERCENTAGE = 20;

    uint8 constant MAX_GENE_LVL = 99; // max dragon gene level

    uint8 constant NUMBER_OF_SPECIAL_PEACEFUL_SKILL_CLASSES = 8; // first is empty skill

    // does dragon have enough DNA points for breeding?
    function isBreedingAllowed(uint8 _level, uint16 _dnaPoints) public view returns (bool) {
        return _level > 0 && _dnaPoints >= params.dnaPoints(_level);
    }

    function _checkIfEnoughPoints(bool _isEnough) internal pure {
        require(_isEnough, "not enough points");
    }

    function _validateSpecialPeacefulSkillClass(uint8 _class) internal pure {
        require(_class > 0 && _class < NUMBER_OF_SPECIAL_PEACEFUL_SKILL_CLASSES, "wrong class of special peaceful skill");
    }

    function _checkIfSpecialPeacefulSkillAvailable(bool _isAvailable) internal pure {
        require(_isAvailable, "special peaceful skill selection is not available");
    }

    function _getBuff(uint256 _id, uint8 _class) internal view returns (uint32) {
        return _storage_.buffs(_id, _class);
    }

    function _getAllBuffs(uint256 _id) internal view returns (uint32[5]) {
        return [
            _getBuff(_id, 1),
            _getBuff(_id, 2),
            _getBuff(_id, 3),
            _getBuff(_id, 4),
            _getBuff(_id, 5)
        ];
    }

    // GETTERS

    function calculateMaxHealthAndManaWithBuffs(uint256 _id) public view returns (
        uint32 maxHealth,
        uint32 maxMana
    ) {
        (, , uint32 _stamina, , uint32 _intelligence) = _storage_.skills(_id);

        (
            maxHealth,
            maxMana
        ) = helper.calculateHealthAndMana(
            _stamina,
            _intelligence,
            _getBuff(_id, 3), // stamina buff
            _getBuff(_id, 5) // intelligence buff
        );
    }

    function getCurrentHealthAndMana(uint256 _id) public view returns (
        uint32 health,
        uint32 mana,
        uint8 healthPercentage,
        uint8 manaPercentage
    ) {
        (
            uint256 _timestamp,
            uint32 _remainingHealth,
            uint32 _remainingMana,
            uint32 _maxHealth,
            uint32 _maxMana
        ) = _storage_.healthAndMana(_id);

        (_maxHealth, _maxMana) = calculateMaxHealthAndManaWithBuffs(_id);

        uint256 _pastTime = now.sub(_timestamp); // solium-disable-line security/no-block-members
        (health, healthPercentage) = helper.calculateCurrent(_pastTime, _maxHealth, _remainingHealth);
        (mana, manaPercentage) = helper.calculateCurrent(_pastTime, _maxMana, _remainingMana);
    }

    // SETTERS

    function setRemainingHealthAndMana(
        uint256 _id,
        uint32 _remainingHealth,
        uint32 _remainingMana
    ) external onlyController {
        _storage_.setRemainingHealthAndMana(_id, _remainingHealth, _remainingMana);
    }

    function increaseExperience(uint256 _id, uint256 _factor) external onlyController {
        (
            uint8 _level,
            uint256 _experience,
            uint16 _dnaPoints
        ) = _storage_.levels(_id);
        uint8 _currentLevel = _level;
        if (_level < MAX_LEVEL) {
            (_level, _experience, _dnaPoints) = helper.calculateExperience(_level, _experience, _dnaPoints, _factor);
            if (_level > _currentLevel) {
                // restore hp and mana if level up
                _storage_.resetHealthAndManaTimestamp(_id);
            }
            if (_level == MAX_LEVEL) {
                _experience = 0;
            }
            _storage_.setLevel(_id, _level, _experience.toUint8(), _dnaPoints);
        }
    }

    function payDNAPointsForBreeding(uint256 _id) external onlyController {
        (
            uint8 _level,
            uint8 _experience,
            uint16 _dnaPoints
        ) = _storage_.levels(_id);

        _checkIfEnoughPoints(isBreedingAllowed(_level, _dnaPoints));
        _dnaPoints = _dnaPoints.sub(params.dnaPoints(_level));

        _storage_.setLevel(_id, _level, _experience, _dnaPoints);
    }

    function upgradeGenes(uint256 _id, uint16[10] _dnaPoints) external onlyController {
        (
            uint8 _level,
            uint8 _experience,
            uint16 _availableDNAPoints
        ) = _storage_.levels(_id);

        uint16 _sum;
        uint256[4] memory _newComposedGenome;
        (
            _newComposedGenome,
            _sum
        ) = helper.upgradeGenes(
            _storage_.getGenome(_id),
            _dnaPoints,
            _availableDNAPoints
        );

        require(_sum > 0, "DNA points were not used");

        _availableDNAPoints = _availableDNAPoints.sub(_sum);
        // save data
        _storage_.setLevel(_id, _level, _experience, _availableDNAPoints);
        _storage_.setGenome(_id, _newComposedGenome);
        _storage_.setCoolness(_id, helper.calculateCoolness(_newComposedGenome));
        // recalculate skills
        _saveSkills(_id, _newComposedGenome);
    }

    function _saveSkills(uint256 _id, uint256[4] _genome) internal {
        (
            uint32 _attack,
            uint32 _defense,
            uint32 _stamina,
            uint32 _speed,
            uint32 _intelligence
        ) = helper.calculateSkills(_genome);
        (
            uint32 _health,
            uint32 _mana
        ) = helper.calculateHealthAndMana(_stamina, _intelligence, 0, 0); // without buffs

        _storage_.setMaxHealthAndMana(_id, _health, _mana);
        _storage_.setSkills(_id, _attack, _defense, _stamina, _speed, _intelligence);
    }

    function increaseWins(uint256 _id) external onlyController {
        (uint16 _wins, ) = _storage_.battles(_id);
        _storage_.setWins(_id, _wins.add(1));
    }

    function increaseDefeats(uint256 _id) external onlyController {
        (, uint16 _defeats) = _storage_.battles(_id);
        _storage_.setDefeats(_id, _defeats.add(1));
    }

    function setTactics(uint256 _id, uint8 _melee, uint8 _attack) external onlyController {
        require(
            _melee >= MIN_TACTICS_PERCENTAGE &&
            _melee <= MAX_TACTICS_PERCENTAGE &&
            _attack >= MIN_TACTICS_PERCENTAGE &&
            _attack <= MAX_TACTICS_PERCENTAGE,
            "tactics value must be between 20 and 80"
        );
        _storage_.setTactics(_id, _melee, _attack);
    }

    function calculateSpecialPeacefulSkill(uint256 _id) public view returns (
        uint8 class,
        uint32 cost,
        uint32 effect
    ) {
        class = _storage_.specialPeacefulSkills(_id);
        if (class == 0) return;
        (
            uint32 _attack,
            uint32 _defense,
            uint32 _stamina,
            uint32 _speed,
            uint32 _intelligence
        ) = _storage_.skills(_id);

        (
            cost,
            effect
        ) = helper.calculateSpecialPeacefulSkill(
            class,
            [_attack, _defense, _stamina, _speed, _intelligence],
            _getAllBuffs(_id)
        );
    }

    function setSpecialPeacefulSkill(uint256 _id, uint8 _class) external onlyController {
        (uint8 _level, , ) = _storage_.levels(_id);
        uint8 _currentClass = _storage_.specialPeacefulSkills(_id);

        _checkIfSpecialPeacefulSkillAvailable(_level == MAX_LEVEL);
        _validateSpecialPeacefulSkillClass(_class);
        _checkIfSpecialPeacefulSkillAvailable(_currentClass == 0);

        _storage_.setSpecialPeacefulSkill(_id, _class);
    }

    function _getBuffIndexBySpecialPeacefulSkillClass(
        uint8 _class
    ) internal pure returns (uint8) {
        uint8[8] memory _buffsIndexes = [0, 1, 2, 3, 4, 5, 3, 5]; // 0 item - no such class
        return _buffsIndexes[_class];
    }

    // _id - dragon, which will use the skill
    // _target - dragon, on which the skill will be used
    // _sender - owner of the first dragon
    function useSpecialPeacefulSkill(address _sender, uint256 _id, uint256 _target) external onlyController {
        (
            uint8 _class,
            uint32 _cost,
            uint32 _effect
        ) = calculateSpecialPeacefulSkill(_id);
        (
            uint32 _health,
            uint32 _mana, ,
        ) = getCurrentHealthAndMana(_id);

        _validateSpecialPeacefulSkillClass(_class);
        // enough mana
        _checkIfEnoughPoints(_mana >= _cost);

        // subtract cost of special peaceful skill
        _storage_.setRemainingHealthAndMana(_id, _health, _mana.sub(_cost));
        // reset intelligence buff of the first dragon
        _storage_.setBuff(_id, 5, 0);
        // reset active skill buff of the first dragon
        uint8 _buffIndexOfActiveSkill = _getBuffIndexBySpecialPeacefulSkillClass(_class);
        _storage_.setBuff(_id, _buffIndexOfActiveSkill, 0);

        if (_class == 6 || _class == 7) { // health/mana restoration
            (
                uint32 _targetHealth,
                uint32 _targetMana, ,
            ) = getCurrentHealthAndMana(_target);
            if (_class == 6) _targetHealth = _targetHealth.add(_effect); // restore health
            if (_class == 7) _targetMana = _targetMana.add(_effect); // restore mana
            // save restored health/mana
            _storage_.setRemainingHealthAndMana(
                _target,
                _targetHealth,
                _targetMana
            );
        } else { // another special peaceful skills
            if (_storage_.ownerOf(_target) != _sender) { // to prevert lower effect buffing
                require(_getBuff(_target, _class) < _effect, "you can't buff alien dragon by lower effect");
            }
            _storage_.setBuff(_target, _class, _effect);
        }
    }

    function setBuff(uint256 _id, uint8 _class, uint32 _effect) external onlyController {
        _storage_.setBuff(_id, _class, _effect);
    }

    function createDragon(
        address _sender,
        uint16 _generation,
        uint256[2] _parents,
        uint256[4] _genome,
        uint8[11] _dragonTypes
    ) external onlyController returns (uint256 newDragonId) {
        newDragonId = _storage_.push(_sender, _generation, _genome, _parents, _dragonTypes);
        uint32 _coolness = helper.calculateCoolness(_genome);
        _storage_.setCoolness(newDragonId, _coolness);
        _storage_.setTactics(newDragonId, 50, 50);
        _setSkillsAndHealthAndMana(newDragonId, _genome, _dragonTypes);
    }

    function setName(
        uint256 _id,
        string _name
    ) external onlyController returns (bytes32) {
        (
            bytes32 _initial, // initial name that converted to bytes32
            bytes32 _lowercase // name to lowercase
        ) = helper.checkAndConvertName(_name);
        require(!_storage_.existingNames(_lowercase), "name exists");
        require(_storage_.names(_id) == 0x0, "dragon already has a name");
        _storage_.setName(_id, _initial, _lowercase);
        return _initial;
    }
}
