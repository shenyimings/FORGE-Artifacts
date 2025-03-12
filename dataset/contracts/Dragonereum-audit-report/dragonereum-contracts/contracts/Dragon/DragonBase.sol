pragma solidity 0.4.25;


import "../Common/Upgradable.sol";
import "../Common/Random.sol";
import "./DragonStorage.sol";
import "./DragonParams.sol";
import "./DragonCoreHelper.sol";
import "../Common/SafeMath32.sol";
import "../Common/SafeMath256.sol";
import "../Common/SafeConvert.sol";

contract DragonBase is Upgradable {
    using SafeMath32 for uint32;
    using SafeMath256 for uint256;
    using SafeConvert for uint32;
    using SafeConvert for uint256;

    DragonStorage _storage_;
    DragonParams params;
    DragonCoreHelper helper;
    Random random;

    function _identifySpecialBattleSkills(
        uint256 _id,
        uint8[11] _dragonTypes
    ) internal {
        uint256 _randomSeed = random.random(10000); // generate 4-digit number in range [0, 9999]
        uint256 _attackRandom = _randomSeed % 100; // 2-digit number (last 2 digits)
        uint256 _defenseRandom = _randomSeed / 100; // 2-digit number (first 2 digits)

        // we have 100 variations of random number but genes only 40, so we calculate random [0..39]
        _attackRandom = _attackRandom.mul(4).div(10);
        _defenseRandom = _defenseRandom.mul(4).div(10);

        uint8 _attackType = helper.getSpecialBattleSkillDragonType(_dragonTypes, _attackRandom);
        uint8 _defenseType = helper.getSpecialBattleSkillDragonType(_dragonTypes, _defenseRandom);

        _storage_.setSpecialAttack(_id, _attackType);
        _storage_.setSpecialDefense(_id, _defenseType);
    }

    function _setSkillsAndHealthAndMana(uint256 _id, uint256[4] _genome, uint8[11] _dragonTypes) internal {
        (
            uint32 _attack,
            uint32 _defense,
            uint32 _stamina,
            uint32 _speed,
            uint32 _intelligence
        ) = helper.calculateSkills(_genome);

        _storage_.setSkills(_id, _attack, _defense, _stamina, _speed, _intelligence);

        _identifySpecialBattleSkills(_id, _dragonTypes);

        (
            uint32 _health,
            uint32 _mana
        ) = helper.calculateHealthAndMana(_stamina, _intelligence, 0, 0);
        _storage_.setMaxHealthAndMana(_id, _health, _mana);
    }

    function setInternalDependencies(address[] _newDependencies) public onlyOwner {
        super.setInternalDependencies(_newDependencies);

        _storage_ = DragonStorage(_newDependencies[0]);
        params = DragonParams(_newDependencies[1]);
        helper = DragonCoreHelper(_newDependencies[2]);
        random = Random(_newDependencies[3]);
    }
}
