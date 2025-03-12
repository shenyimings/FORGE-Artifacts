pragma solidity 0.4.25;

import "../Common/ERC721/ERC721Token.sol";
import "./DragonModel.sol";

contract DragonStorage is DragonModel, ERC721Token {
    Dragon[] public dragons;
    // existing names
    mapping (bytes32 => bool) public existingNames;
    mapping (uint256 => bytes32) public names;

    mapping (uint256 => HealthAndMana) public healthAndMana;
    mapping (uint256 => Tactics) public tactics;
    mapping (uint256 => Battles) public battles;
    mapping (uint256 => Skills) public skills;
    mapping (uint256 => Level) public levels;
    mapping (uint256 => uint32) public coolness; // Dragon Skillfulness Index in the WP

    // id -> type of skill (dragon type)
    mapping (uint256 => uint8) public specialAttacks;
    mapping (uint256 => uint8) public specialDefenses;


    // classes:
    // 0 - no skill
    // 1 - attack boost
    // 2 - defense boost
    // 3 - stamina boost
    // 4 - speed boost
    // 5 - intelligence boost
    // 6 - healing
    // 7 - mana recharge

    // id -> class
    mapping (uint256 => uint8) public specialPeacefulSkills;


    // classes:
    // 1 - attack
    // 2 - defense
    // 3 - stamina
    // 4 - speed
    // 5 - intelligence
    //
    // id -> class -> effect
    mapping (uint256 => mapping (uint8 => uint32)) public buffs;



    constructor(string _name, string _symbol) public ERC721Token(_name, _symbol) {
        dragons.length = 1; // to avoid some issues with 0
    }

    // GETTERS

    function length() external view returns (uint256) {
        return dragons.length;
    }

    function getGenome(uint256 _id) external view returns (uint256[4]) {
        return dragons[_id].genome;
    }

    function getParents(uint256 _id) external view returns (uint256[2]) {
        return dragons[_id].parents;
    }

    function getDragonTypes(uint256 _id) external view returns (uint8[11]) {
        return dragons[_id].types;
    }

    // SETTERS

    function push(
        address _sender,
        uint16 _generation,
        uint256[4] _genome,
        uint256[2] _parents,
        uint8[11] _types
    ) public onlyController returns (uint256 id) {
        id = dragons.push(Dragon({
            generation: _generation,
            genome: _genome,
            parents: _parents,
            types: _types,
            birth: now // solium-disable-line security/no-block-members
        })).sub(1);
        _mint(_sender, id);
    }

    function setName(
        uint256 _id,
        bytes32 _name,
        bytes32 _lowercase
    ) external onlyController {
        names[_id] = _name;
        existingNames[_lowercase] = true;
    }

    function setTactics(uint256 _id, uint8 _melee, uint8 _attack) external onlyController {
        tactics[_id].melee = _melee;
        tactics[_id].attack = _attack;
    }

    function setWins(uint256 _id, uint16 _value) external onlyController {
        battles[_id].wins = _value;
    }

    function setDefeats(uint256 _id, uint16 _value) external onlyController {
        battles[_id].defeats = _value;
    }

    function setMaxHealthAndMana(
        uint256 _id,
        uint32 _maxHealth,
        uint32 _maxMana
    ) external onlyController {
        healthAndMana[_id].maxHealth = _maxHealth;
        healthAndMana[_id].maxMana = _maxMana;
    }

    function setRemainingHealthAndMana(
        uint256 _id,
        uint32 _remainingHealth,
        uint32 _remainingMana
    ) external onlyController {
        healthAndMana[_id].timestamp = now; // solium-disable-line security/no-block-members
        healthAndMana[_id].remainingHealth = _remainingHealth;
        healthAndMana[_id].remainingMana = _remainingMana;
    }

    function resetHealthAndManaTimestamp(uint256 _id) external onlyController {
        healthAndMana[_id].timestamp = 0;
    }

    function setSkills(
        uint256 _id,
        uint32 _attack,
        uint32 _defense,
        uint32 _stamina,
        uint32 _speed,
        uint32 _intelligence
    ) external onlyController {
        skills[_id].attack = _attack;
        skills[_id].defense = _defense;
        skills[_id].stamina = _stamina;
        skills[_id].speed = _speed;
        skills[_id].intelligence = _intelligence;
    }

    function setLevel(uint256 _id, uint8 _level, uint8 _experience, uint16 _dnaPoints) external onlyController {
        levels[_id].level = _level;
        levels[_id].experience = _experience;
        levels[_id].dnaPoints = _dnaPoints;
    }

    function setCoolness(uint256 _id, uint32 _coolness) external onlyController {
        coolness[_id] = _coolness;
    }

    function setGenome(uint256 _id, uint256[4] _genome) external onlyController {
        dragons[_id].genome = _genome;
    }

    function setSpecialAttack(
        uint256 _id,
        uint8 _dragonType
    ) external onlyController {
        specialAttacks[_id] = _dragonType;
    }

    function setSpecialDefense(
        uint256 _id,
        uint8 _dragonType
    ) external onlyController {
        specialDefenses[_id] = _dragonType;
    }

    function setSpecialPeacefulSkill(
        uint256 _id,
        uint8 _class
    ) external onlyController {
        specialPeacefulSkills[_id] = _class;
    }

    function setBuff(uint256 _id, uint8 _class, uint32 _effect) external onlyController {
        buffs[_id][_class] = _effect;
    }
}
