pragma solidity 0.4.25;


import "../BattleController.sol";

contract BattleControllerMock is BattleController {

    function isTouchable(uint id) public view returns (bool) {
        return _isTouchable(id);
    }

    function calculateExperience(
        bool _isAttackerWinner,
        uint32 _attackerStrength,
        uint32 _opponentStrength
    ) public pure returns (uint256) {
        return _calculateExperience(_isAttackerWinner, _attackerStrength, _opponentStrength);
    }

    function payGoldReward(address _sender, uint256 _id, uint256 _factor ) public {
        return _payGoldReward( _sender, _id, _factor);
    }

    function calculateGoldRewardFactor(uint256 _ws, uint256 _ls) public pure returns (uint256) {
        return _calculateGoldRewardFactor(_ws, _ls);
    }
}
