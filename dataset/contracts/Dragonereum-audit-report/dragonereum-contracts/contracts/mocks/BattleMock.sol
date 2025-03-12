pragma solidity 0.4.25;


import "../Battle.sol";

contract BattleMock is Battle {

    function calculateDragonTypeMultiply(uint8[11] _attackerTypesArray, uint8[11] _defenderTypesArray) public pure returns (uint32) {
        return _calculateDragonTypeMultiply(_attackerTypesArray, _defenderTypesArray);
    }

    function initDragon(
        uint256 _id,
        uint256 _opponentId,
        uint8[2] _tactics,
        bool _isGladiator
    ) public view returns ( uint32 attack, uint32 defense, uint32 health, uint32 speed, uint32 mana) {
        Dragon memory dragon;
        dragon = _initDragon(_id, _opponentId, _tactics, _isGladiator);
        attack = dragon.attack;
        defense = dragon.defense;
        health = dragon.health;
        speed = dragon.speed;
        mana = dragon.mana;
    }

    function initBaseDragon(
        uint256 _id,
        uint256 _opponentId,
        uint8 _meleeChance,
        uint8 _attackChance,
        bool _isGladiator
    ) public view returns (uint32 attack) {
        Dragon memory dragon;
        dragon = _initBaseDragon(_id, _opponentId, _meleeChance, _attackChance, _isGladiator);
        attack = dragon.attack;
    }
}
