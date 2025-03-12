pragma solidity 0.4.25;

import "../GladiatorBattle/Participants/GladiatorBattle.sol";

contract GladiatorBattleMock is GladiatorBattle {

    function setAUTO_SELECT_TIME(uint _c) public {
        AUTO_SELECT_TIME = _c;
    }
}
