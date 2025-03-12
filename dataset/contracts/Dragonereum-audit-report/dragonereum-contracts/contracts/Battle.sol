pragma solidity 0.4.25;


import "./Common/Upgradable.sol";
import "./Getter.sol";
import "./Common/SafeMath8.sol";
import "./Common/SafeMath32.sol";
import "./Common/SafeMath256.sol";
import "./Common/SafeConvert.sol";

contract Battle is Upgradable {
    using SafeMath8 for uint8;
    using SafeMath32 for uint32;
    using SafeMath256 for uint256;
    using SafeConvert for uint256;

    Getter getter;

    struct Dragon {
        uint256 id;
        uint8 attackChance;
        uint8 meleeChance;
        uint32 health;
        uint32 mana;
        uint32 speed;
        uint32 attack;
        uint32 defense;
        uint32 specialAttackCost;
        uint8 specialAttackFactor;
        uint8 specialAttackChance;
        uint32 specialDefenseCost;
        uint8 specialDefenseFactor;
        uint8 specialDefenseChance;
        bool blocking;
        bool specialBlocking;
    }

    uint8 constant __FLOAT_NUMBER_MULTIPLY = 10;

    // We have to divide each calculations
    // with "__" postfix by __FLOAT_NUMBER_MULTIPLY
    uint8 constant DISTANCE_ATTACK_WEAK__ = 8; // 0.8
    uint8 constant DEFENSE_SUCCESS_MULTIPLY__ = 10; // 1
    uint8 constant DEFENSE_FAIL_MULTIPLY__ = 2; // 0.2
    uint8 constant FALLBACK_SPEED_FACTOR__ = 7; // 0.7

    uint32 constant MAX_MELEE_ATTACK_DISTANCE = 100; // 1, multiplied as skills
    uint32 constant MIN_RANGE_ATTACK_DISTANCE = 300; // 3, multiplied as skills

    uint8 constant MAX_TURNS = 70;

    uint8 constant DRAGON_TYPE_FACTOR = 5; // 0.5

    uint16 constant DRAGON_TYPE_MULTIPLY = 1600;

    uint8 constant PERCENT_MULTIPLIER = 100;


    uint256 battlesCounter;

    // values in the range of 0..99
    function _getRandomNumber(
        uint256 _initialSeed,
        uint256 _currentSeed_
    ) internal pure returns(uint8, uint256) {
        uint256 _currentSeed = _currentSeed_;
        if (_currentSeed == 0) {
            _currentSeed = _initialSeed;
        }
        uint8 _random = (_currentSeed % 100).toUint8();
        _currentSeed = _currentSeed.div(100);
        return (_random, _currentSeed);
    }

    function _safeSub(uint32 a, uint32 b) internal pure returns(uint32) {
        return b > a ? 0 : a.sub(b);
    }

    function _multiplyByFloatNumber(uint32 _number, uint8 _multiplier) internal pure returns (uint32) {
        return _number.mul(_multiplier).div(__FLOAT_NUMBER_MULTIPLY);
    }

    function _calculatePercentage(uint32 _part, uint32 _full) internal pure returns (uint32) {
        return _part.mul(PERCENT_MULTIPLIER).div(_full);
    }

    function _calculateDragonTypeMultiply(uint8[11] _attackerTypesArray, uint8[11] _defenderTypesArray) internal pure returns (uint32) {
        uint32 dragonTypeSumMultiply = 0;
        uint8 _currentDefenderType;
        uint32 _dragonTypeMultiply;

        for (uint8 _attackerType = 0; _attackerType < _attackerTypesArray.length; _attackerType++) {
            if (_attackerTypesArray[_attackerType] != 0) {
                for (uint8 _defenderType = 0; _defenderType < _defenderTypesArray.length; _defenderType++) {
                    if (_defenderTypesArray[_defenderType] != 0) {
                        _currentDefenderType = _defenderType;

                        if (_currentDefenderType < _attackerType) {
                            _currentDefenderType = _currentDefenderType.add(_defenderTypesArray.length.toUint8());
                        }

                        if (_currentDefenderType.add(_attackerType).add(1) % 2 == 0) {
                            _dragonTypeMultiply = _attackerTypesArray[_attackerType];
                            _dragonTypeMultiply = _dragonTypeMultiply.mul(_defenderTypesArray[_defenderType]);
                            dragonTypeSumMultiply = dragonTypeSumMultiply.add(_dragonTypeMultiply);
                        }
                    }
                }
            }
        }

        return _multiplyByFloatNumber(dragonTypeSumMultiply, DRAGON_TYPE_FACTOR).add(DRAGON_TYPE_MULTIPLY);
    }

    function _initBaseDragon(
        uint256 _id,
        uint256 _opponentId,
        uint8 _meleeChance,
        uint8 _attackChance,
        bool _isGladiator
    ) internal view returns (Dragon) {
        uint32 _health;
        uint32 _mana;
        if (_isGladiator) {
            (_health, _mana) = getter.getDragonMaxHealthAndMana(_id);
        } else {
            (_health, _mana, , ) = getter.getDragonCurrentHealthAndMana(_id);
        }

        if (_meleeChance == 0 || _attackChance == 0) {
            (_meleeChance, _attackChance) = getter.getDragonTactics(_id);
        }
        uint8[11] memory _attackerTypes = getter.getDragonTypes(_id);
        uint8[11] memory _opponentTypes = getter.getDragonTypes(_opponentId);
        uint32 _attack;
        uint32 _defense;
        uint32 _speed;
        (_attack, _defense, , _speed, ) = getter.getDragonSkills(_id);

        return Dragon({
            id: _id,
            attackChance: _attackChance,
            meleeChance: _meleeChance,
            health: _health,
            mana: _mana,
            speed: _speed,
            attack: _attack.mul(_calculateDragonTypeMultiply(_attackerTypes, _opponentTypes)).div(DRAGON_TYPE_MULTIPLY),
            defense: _defense,
            specialAttackCost: 0,
            specialAttackFactor: 0,
            specialAttackChance: 0,
            specialDefenseCost: 0,
            specialDefenseFactor: 0,
            specialDefenseChance: 0,
            blocking: false,
            specialBlocking: false
        });
    }

    function _initDragon(
        uint256 _id,
        uint256 _opponentId,
        uint8[2] _tactics,
        bool _isGladiator
    ) internal view returns (Dragon dragon) {
        dragon = _initBaseDragon(_id, _opponentId, _tactics[0], _tactics[1], _isGladiator);

        uint32 _specialAttackCost;
        uint8 _specialAttackFactor;
        uint8 _specialAttackChance;
        uint32 _specialDefenseCost;
        uint8 _specialDefenseFactor;
        uint8 _specialDefenseChance;

        ( , _specialAttackCost, _specialAttackFactor, _specialAttackChance) = getter.getDragonSpecialAttack(_id);
        ( , _specialDefenseCost, _specialDefenseFactor, _specialDefenseChance) = getter.getDragonSpecialDefense(_id);

        dragon.specialAttackCost = _specialAttackCost;
        dragon.specialAttackFactor = _specialAttackFactor;
        dragon.specialAttackChance = _specialAttackChance;
        dragon.specialDefenseCost = _specialDefenseCost;
        dragon.specialDefenseFactor = _specialDefenseFactor;
        dragon.specialDefenseChance = _specialDefenseChance;

        uint32[5] memory _buffs = getter.getDragonBuffs(_id);

        if (_buffs[0] > 0) {
            dragon.attack = dragon.attack.mul(_buffs[0]).div(100);
        }
        if (_buffs[1] > 0) {
            dragon.defense = dragon.defense.mul(_buffs[1]).div(100);
        }
        if (_buffs[3] > 0) {
            dragon.speed = dragon.speed.mul(_buffs[3]).div(100);
        }
    }

    function _resetBlocking(Dragon dragon) internal pure returns (Dragon) {
        dragon.blocking = false;
        dragon.specialBlocking = false;

        return dragon;
    }

    function _attack(
        uint8 turnId,
        bool isMelee,
        Dragon attacker,
        Dragon opponent,
        uint8 _random
    ) internal pure returns (
        Dragon,
        Dragon
    ) {

        uint8 _turnModificator = 10; // multiplied by 10
        if (turnId > 30) {
            uint256 _modif = uint256(turnId).sub(30);
            _modif = _modif.mul(50);
            _modif = _modif.div(40);
            _modif = _modif.add(10);
            _turnModificator = _modif.toUint8();
        }

        bool isSpecial = _random < _multiplyByFloatNumber(attacker.specialAttackChance, _turnModificator);

        uint32 damage = _multiplyByFloatNumber(attacker.attack, _turnModificator);

        if (isSpecial && attacker.mana >= attacker.specialAttackCost) {
            attacker.mana = attacker.mana.sub(attacker.specialAttackCost);
            damage = _multiplyByFloatNumber(damage, attacker.specialAttackFactor);
        }

        if (!isMelee) {
            damage = _multiplyByFloatNumber(damage, DISTANCE_ATTACK_WEAK__);
        }

        uint32 defense = opponent.defense;

        if (opponent.blocking) {
            defense = _multiplyByFloatNumber(defense, DEFENSE_SUCCESS_MULTIPLY__);

            if (opponent.specialBlocking) {
                defense = _multiplyByFloatNumber(defense, opponent.specialDefenseFactor);
            }
        } else {
            defense = _multiplyByFloatNumber(defense, DEFENSE_FAIL_MULTIPLY__);
        }

        if (damage > defense) {
            opponent.health = _safeSub(opponent.health, damage.sub(defense));
        } else if (isMelee) {
            attacker.health = _safeSub(attacker.health, defense.sub(damage));
        }

        return (attacker, opponent);
    }

    function _defense(
        Dragon attacker,
        uint256 initialSeed,
        uint256 currentSeed
    ) internal pure returns (
        Dragon,
        uint256
    ) {
        uint8 specialRandom;

        (specialRandom, currentSeed) = _getRandomNumber(initialSeed, currentSeed);
        bool isSpecial = specialRandom < attacker.specialDefenseChance;

        if (isSpecial && attacker.mana >= attacker.specialDefenseCost) {
            attacker.mana = attacker.mana.sub(attacker.specialDefenseCost);
            attacker.specialBlocking = true;
        }
        attacker.blocking = true;

        return (attacker, currentSeed);
    }

    /* solium-disable-next-line security/no-assign-params */
    function _turn(
        uint8 turnId,
        uint256 initialSeed,
        uint256 currentSeed,
        uint32 distance,
        Dragon currentDragon,
        Dragon currentEnemy
    ) internal view returns (
        Dragon winner,
        Dragon looser
    ) {
        uint8 rand;

        (rand, currentSeed) = _getRandomNumber(initialSeed, currentSeed);
        bool isAttack = rand < currentDragon.attackChance;

        if (isAttack) {
            (rand, currentSeed) = _getRandomNumber(initialSeed, currentSeed);
            bool isMelee = rand < currentDragon.meleeChance;

            if (isMelee && distance > MAX_MELEE_ATTACK_DISTANCE) {
                distance = _safeSub(distance, currentDragon.speed);
            } else if (!isMelee && distance < MIN_RANGE_ATTACK_DISTANCE) {
                distance = distance.add(_multiplyByFloatNumber(currentDragon.speed, FALLBACK_SPEED_FACTOR__));
            } else {
                (rand, currentSeed) = _getRandomNumber(initialSeed, currentSeed);
                (currentDragon, currentEnemy) = _attack(turnId, isMelee, currentDragon, currentEnemy, rand);
            }
        } else {
            (currentDragon, currentSeed) = _defense(currentDragon, initialSeed, currentSeed);
        }

        currentEnemy = _resetBlocking(currentEnemy);

        if (currentDragon.health == 0) {
            return (currentEnemy, currentDragon);
        } else if (currentEnemy.health == 0) {
            return (currentDragon, currentEnemy);
        } else if (turnId < MAX_TURNS) {
            return _turn(turnId.add(1), initialSeed, currentSeed, distance, currentEnemy, currentDragon);
        } else {
            uint32 _dragonMaxHealth;
            uint32 _enemyMaxHealth;
            (_dragonMaxHealth, ) = getter.getDragonMaxHealthAndMana(currentDragon.id);
            (_enemyMaxHealth, ) = getter.getDragonMaxHealthAndMana(currentEnemy.id);
            if (_calculatePercentage(currentDragon.health, _dragonMaxHealth) >= _calculatePercentage(currentEnemy.health, _enemyMaxHealth)) {
                return (currentDragon, currentEnemy);
            } else {
                return (currentEnemy, currentDragon);
            }
        }
    }

    function _start(
        uint256 _firstDragonId,
        uint256 _secondDragonId,
        uint8[2] _firstTactics,
        uint8[2] _secondTactics,
        uint256 _seed,
        bool _isGladiator
    ) internal view returns (
        uint256[2],
        uint32,
        uint32,
        uint32,
        uint32
    ) {
        Dragon memory _firstDragon = _initDragon(_firstDragonId, _secondDragonId, _firstTactics, _isGladiator);
        Dragon memory _secondDragon = _initDragon(_secondDragonId, _firstDragonId, _secondTactics, _isGladiator);

        if (_firstDragon.speed >= _secondDragon.speed) {
            (_firstDragon, _secondDragon) = _turn(1, _seed, _seed, MAX_MELEE_ATTACK_DISTANCE, _firstDragon, _secondDragon);
        } else {
            (_firstDragon, _secondDragon) = _turn(1, _seed, _seed, MAX_MELEE_ATTACK_DISTANCE, _secondDragon, _firstDragon);
        }

        return (
            [_firstDragon.id,  _secondDragon.id],
            _firstDragon.health,
            _firstDragon.mana,
            _secondDragon.health,
            _secondDragon.mana
        );
    }

    function start(
        uint256 _firstDragonId,
        uint256 _secondDragonId,
        uint8[2] _tactics,
        uint8[2] _tactics2,
        uint256 _seed,
        bool _isGladiator
    ) external onlyController returns (
        uint256[2] winnerLooserIds,
        uint32 winnerHealth,
        uint32 winnerMana,
        uint32 looserHealth,
        uint32 looserMana,
        uint256 battleId
    ) {

        (
            winnerLooserIds,
            winnerHealth,
            winnerMana,
            looserHealth,
            looserMana
        ) = _start(
            _firstDragonId,
            _secondDragonId,
            _tactics,
            _tactics2,
            _seed,
            _isGladiator
        );

        battleId = battlesCounter;
        battlesCounter = battlesCounter.add(1);
    }

    function setInternalDependencies(address[] _newDependencies) public onlyOwner {
        super.setInternalDependencies(_newDependencies);

        getter = Getter(_newDependencies[0]);
    }
}
