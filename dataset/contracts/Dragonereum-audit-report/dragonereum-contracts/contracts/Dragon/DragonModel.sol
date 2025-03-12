pragma solidity 0.4.25;


contract DragonModel {

    // ** multiplying is necessary for more accurate calculations

    // health and mana are multiplied by 100
    struct HealthAndMana {
        uint256 timestamp; // timestamp of last update
        uint32 remainingHealth; // remaining at last update
        uint32 remainingMana; // remaining at last update
        uint32 maxHealth;
        uint32 maxMana;
    }

    struct Level {
        uint8 level; // current level of dragon
        uint8 experience; // exp at current level
        uint16 dnaPoints; // DNA points
    }

    struct Tactics {
        uint8 melee; // ranged/melee tactics in percentages
        uint8 attack; // defense/attack tactics in percentages
    }

    struct Battles {
        uint16 wins;
        uint16 defeats;
    }

    // multilpied by 100
    struct Skills {
        uint32 attack;
        uint32 defense;
        uint32 stamina;
        uint32 speed;
        uint32 intelligence;
    }

    // types:
    // 0 - water
    // 1 - fire
    // 2 - air
    // 3 - earth
    // 4 - cyber

    struct Dragon {
        uint16 generation;
        uint256[4] genome; // composed genome
        uint256[2] parents;
        uint8[11] types; // array of weights of dragon's types
        uint256 birth; // timestamp
    }

}
