pragma solidity 0.4.25;

import "./Common/Upgradable.sol";
import "./Common/Pausable.sol";
import "./Common/HumanOriented.sol";
import "./BattleController.sol";
import "./GladiatorBattle/Participants/GladiatorBattle.sol";
import "./GladiatorBattle/Spectators/GladiatorBattleSpectators.sol";
import "./Events.sol";

contract MainBattle is Upgradable, Pausable, HumanOriented {
    BattleController battleController;
    Getter getter;
    GladiatorBattle gladiatorBattle;
    GladiatorBattleSpectators gladiatorBattleSpectators;
    Events events;

    function matchOpponents(uint256 _id) external view returns (uint256[6]) {
        return battleController.matchOpponents(_id);
    }

    function battle(
        uint256 _id,
        uint256 _opponentId,
        uint8[2] _tactics
    ) external onlyHuman whenNotPaused {
        uint32 _attackerInitHealth;
        uint32 _attackerInitMana;
        uint32 _opponentInitHealth;
        uint32 _opponentInitMana;
        (_attackerInitHealth, _attackerInitMana, , ) = getter.getDragonCurrentHealthAndMana(_id);
        (_opponentInitHealth, _opponentInitMana, , ) = getter.getDragonCurrentHealthAndMana(_opponentId);

        uint256 _battleId;
        uint256 _seed;
        uint256[2] memory _winnerLooserIds;
        (
            _battleId,
            _seed,
            _winnerLooserIds
        ) = battleController.startBattle(msg.sender, _id, _opponentId, _tactics);

        _emitBattleEventsPure(
            _id,
            _opponentId,
            _tactics,
            _winnerLooserIds,
            _battleId,
            _seed,
            _attackerInitHealth,
            _attackerInitMana,
            _opponentInitHealth,
            _opponentInitMana
        );
    }

    function _emitBattleEventsPure(
        uint256 _id,
        uint256 _opponentId,
        uint8[2] _tactics,
        uint256[2] _winnerLooserIds,
        uint256 _battleId,
        uint256 _seed,
        uint32 _attackerInitHealth,
        uint32 _attackerInitMana,
        uint32 _opponentInitHealth,
        uint32 _opponentInitMana
    ) internal {
        _saveBattleHealthAndMana(
            _battleId,
            _id,
            _opponentId,
            _attackerInitHealth,
            _attackerInitMana,
            _opponentInitHealth,
            _opponentInitMana
        );
        _emitBattleEvents(
            _id,
            _opponentId,
            _tactics,
            [0, 0],
            _winnerLooserIds[0],
            _winnerLooserIds[1],
            _battleId,
            _seed,
            0
        );
    }

    function _emitBattleEventsForGladiatorBattle(
        uint256 _battleId,
        uint256 _seed,
        uint256 _gladiatorBattleId
    ) internal {
        uint256 _firstDragonId;
        uint256 _secondDragonId;
        uint256 _winnerDragonId;
        (
          , _firstDragonId,
          , _secondDragonId,
          , _winnerDragonId
        ) = getter.getGladiatorBattleParticipants(_gladiatorBattleId);

        _saveBattleHealthAndManaFull(
            _battleId,
            _firstDragonId,
            _secondDragonId
        );

        uint8[2] memory _tactics;
        uint8[2] memory _tactics2;

        ( , _tactics, ) = getter.getDragonApplicationForGladiatorBattle(_firstDragonId);
        ( , _tactics2, ) = getter.getDragonApplicationForGladiatorBattle(_secondDragonId);

        _emitBattleEvents(
            _firstDragonId,
            _secondDragonId,
            _tactics,
            _tactics2,
            _winnerDragonId,
            _winnerDragonId != _firstDragonId ? _firstDragonId : _secondDragonId,
            _battleId,
            _seed,
            _gladiatorBattleId
        );
    }

    function _emitBattleEvents(
        uint256 _id,
        uint256 _opponentId,
        uint8[2] _tactics,
        uint8[2] _tactics2,
        uint256 _winnerId,
        uint256 _looserId,
        uint256 _battleId,
        uint256 _seed,
        uint256 _gladiatorBattleId
    ) internal {
        _saveBattleData(
            _battleId,
            _seed,
            _id,
            _winnerId,
            _looserId,
            _gladiatorBattleId
        );

        _saveBattleDragonsDetails(
            _battleId,
            _id,
            _opponentId
        );

        _saveBattleSkills(
            _battleId,
            _id,
            _opponentId
        );
        _saveBattleTacticsAndBuffs(
            _battleId,
            _id,
            _opponentId,
            _tactics[0],
            _tactics[1],
            _tactics2[0],
            _tactics2[1]
        );
    }

    function _saveBattleData(
        uint256 _battleId,
        uint256 _seed,
        uint256 _attackerId,
        uint256 _winnerId,
        uint256 _looserId,
        uint256 _gladiatorBattleId
    ) internal {

        events.emitBattleEnded(
            _battleId,
            now, // solium-disable-line security/no-block-members
            _seed,
            _attackerId,
            _winnerId,
            _looserId,
            _gladiatorBattleId > 0,
            _gladiatorBattleId
        );
    }

    function _saveBattleDragonsDetails(
        uint256 _battleId,
        uint256 _winnerId,
        uint256 _looserId
    ) internal {
        uint8 _winnerLevel;
        uint32 _winnerCoolness;
        uint8 _looserLevel;
        uint32 _looserCoolness;
        (, , , _winnerLevel, , , , _winnerCoolness) = getter.getDragonProfile(_winnerId);
        (, , , _looserLevel, , , , _looserCoolness) = getter.getDragonProfile(_looserId);

        events.emitBattleDragonsDetails(
            _battleId,
            _winnerLevel,
            _winnerCoolness,
            _looserLevel,
            _looserCoolness
        );
    }

    function _saveBattleHealthAndManaFull(
        uint256 _battleId,
        uint256 _firstId,
        uint256 _secondId
    ) internal {
        uint32 _firstInitHealth;
        uint32 _firstInitMana;
        uint32 _secondInitHealth;
        uint32 _secondInitMana;

        (_firstInitHealth, _firstInitMana) = getter.getDragonMaxHealthAndMana(_firstId);
        (_secondInitHealth, _secondInitMana) = getter.getDragonMaxHealthAndMana(_secondId);

        _saveBattleHealthAndMana(
            _battleId,
            _firstId,
            _secondId,
            _firstInitHealth,
            _firstInitMana,
            _secondInitHealth,
            _secondInitMana
        );
    }

    function _saveBattleHealthAndMana(
        uint256 _battleId,
        uint256 _attackerId,
        uint256 _opponentId,
        uint32 _attackerInitHealth,
        uint32 _attackerInitMana,
        uint32 _opponentInitHealth,
        uint32 _opponentInitMana
    ) internal {
        uint32 _attackerMaxHealth;
        uint32 _attackerMaxMana;
        uint32 _opponentMaxHealth;
        uint32 _opponentMaxMana;
        (_attackerMaxHealth, _attackerMaxMana) = getter.getDragonMaxHealthAndMana(_attackerId);
        (_opponentMaxHealth, _opponentMaxMana) = getter.getDragonMaxHealthAndMana(_opponentId);

        events.emitBattleHealthAndMana(
            _battleId,
            _attackerMaxHealth,
            _attackerMaxMana,
            _attackerInitHealth,
            _attackerInitMana,
            _opponentMaxHealth,
            _opponentMaxMana,
            _opponentInitHealth,
            _opponentInitMana
        );
    }

    function _saveBattleSkills(
        uint256 _battleId,
        uint256 _attackerId,
        uint256 _opponentId
    ) internal {
        uint32 _attackerAttack;
        uint32 _attackerDefense;
        uint32 _attackerStamina;
        uint32 _attackerSpeed;
        uint32 _attackerIntelligence;
        uint32 _opponentAttack;
        uint32 _opponentDefense;
        uint32 _opponentStamina;
        uint32 _opponentSpeed;
        uint32 _opponentIntelligence;

        (
            _attackerAttack,
            _attackerDefense,
            _attackerStamina,
            _attackerSpeed,
            _attackerIntelligence
        ) = getter.getDragonSkills(_attackerId);
        (
            _opponentAttack,
            _opponentDefense,
            _opponentStamina,
            _opponentSpeed,
            _opponentIntelligence
        ) = getter.getDragonSkills(_opponentId);

        events.emitBattleSkills(
            _battleId,
            _attackerAttack,
            _attackerDefense,
            _attackerStamina,
            _attackerSpeed,
            _attackerIntelligence,
            _opponentAttack,
            _opponentDefense,
            _opponentStamina,
            _opponentSpeed,
            _opponentIntelligence
        );
    }

    function _saveBattleTacticsAndBuffs(
        uint256 _battleId,
        uint256 _id,
        uint256 _opponentId,
        uint8 _attackerMeleeChance,
        uint8 _attackerAttackChance,
        uint8 _opponentMeleeChance,
        uint8 _opponentAttackChance
    ) internal {
        if (_opponentMeleeChance == 0 || _opponentAttackChance == 0) {
            (
                _opponentMeleeChance,
                _opponentAttackChance
            ) = getter.getDragonTactics(_opponentId);
        }

        uint32[5] memory _buffs = getter.getDragonBuffs(_id);
        uint32[5] memory _opponentBuffs = getter.getDragonBuffs(_opponentId);

        battleController.resetDragonBuffs(_id);
        battleController.resetDragonBuffs(_opponentId);

        events.emitBattleTacticsAndBuffs(
            _battleId,
            _attackerMeleeChance,
            _attackerAttackChance,
            _opponentMeleeChance,
            _opponentAttackChance,
            _buffs,
            _opponentBuffs
        );
    }

    // GLADIATOR BATTLES

    function createGladiatorBattle(
        uint256 _dragonId,
        uint8[2] _tactics,
        bool _isGold,
        uint256 _bet,
        uint16 _counter
    ) external payable onlyHuman whenNotPaused {
        address(gladiatorBattle).transfer(msg.value);
        uint256 _id = gladiatorBattle.create(msg.sender, _dragonId, _tactics, _isGold, _bet, _counter, msg.value);
        events.emitGladiatorBattleCreated(_id, msg.sender, _dragonId, _bet, _isGold);
    }

    function applyForGladiatorBattle(
        uint256 _battleId,
        uint256 _dragonId,
        uint8[2] _tactics
    ) external payable onlyHuman whenNotPaused {
        address(gladiatorBattle).transfer(msg.value);
        gladiatorBattle.apply(_battleId, msg.sender, _dragonId, _tactics, msg.value);
        events.emitGladiatorBattleApplicantAdded(_battleId, msg.sender, _dragonId);
    }

    function chooseOpponentForGladiatorBattle(
        uint256 _battleId,
        uint256 _opponentId,
        bytes32 _applicantsHash
    ) external onlyHuman whenNotPaused {
        gladiatorBattle.chooseOpponent(msg.sender, _battleId, _opponentId, _applicantsHash);
        events.emitGladiatorBattleOpponentSelected(_battleId, _opponentId);
    }

    function autoSelectOpponentForGladiatorBattle(
        uint256 _battleId,
        bytes32 _applicantsHash
    ) external onlyHuman whenNotPaused {
        uint256 _opponentId = gladiatorBattle.autoSelectOpponent(_battleId, _applicantsHash);
        events.emitGladiatorBattleOpponentSelected(_battleId, _opponentId);
    }

    function _emitGladiatorBattleEnded(
        uint256 _gladiatorBattleId,
        uint256 _battleId,
        address _winner,
        address _looser,
        uint256 _reward,
        bool _isGold
    ) internal {
        events.emitGladiatorBattleEnded(
            _gladiatorBattleId,
            _battleId,
            _winner,
            _looser,
            _reward,
            _isGold
        );
    }

    function startGladiatorBattle(
        uint256 _gladiatorBattleId
    ) external onlyHuman whenNotPaused returns (uint256) {
        (
            uint256 _seed,
            uint256 _battleId,
            uint256 _reward,
            bool _isGold
        ) = gladiatorBattle.start(_gladiatorBattleId);

        (
            address _firstUser, ,
            address _secondUser, ,
            address _winner,
            uint256 _winnerId
        ) = getter.getGladiatorBattleParticipants(_gladiatorBattleId);

        _emitGladiatorBattleEnded(
            _gladiatorBattleId,
            _battleId,
            _winner,
            _winner != _firstUser ? _firstUser : _secondUser,
            _reward,
            _isGold
        );

        _emitBattleEventsForGladiatorBattle(
            _battleId,
            _seed,
            _gladiatorBattleId
        );

        return _winnerId;
    }

    function cancelGladiatorBattle(
        uint256 _battleId,
        bytes32 _applicantsHash
    ) external onlyHuman whenNotPaused {
        gladiatorBattle.cancel(msg.sender, _battleId, _applicantsHash);
        events.emitGladiatorBattleCancelled(_battleId);
    }

    function returnBetFromGladiatorBattle(uint256 _battleId) external onlyHuman whenNotPaused {
        gladiatorBattle.returnBet(msg.sender, _battleId);
        events.emitGladiatorBattleBetReturned(_battleId, msg.sender);
    }

    function addTimeForOpponentSelectForGladiatorBattle(uint256 _battleId) external onlyHuman whenNotPaused {
        uint256 _blockNumber = gladiatorBattle.addTimeForOpponentSelect(msg.sender, _battleId);
        events.emitGladiatorBattleOpponentSelectTimeUpdated(_battleId, _blockNumber);
    }

    function updateBlockNumberOfGladiatorBattle(uint256 _battleId) external onlyHuman whenNotPaused {
        uint256 _blockNumber = gladiatorBattle.updateBattleBlockNumber(_battleId);
        events.emitGladiatorBattleBlockNumberUpdated(_battleId, _blockNumber);
    }

    function placeSpectatorBetOnGladiatorBattle(
        uint256 _battleId,
        bool _willCreatorWin,
        uint256 _value
    ) external payable onlyHuman whenNotPaused {
        address(gladiatorBattleSpectators).transfer(msg.value);
        bool _isGold = gladiatorBattleSpectators.placeBet(msg.sender, _battleId, _willCreatorWin, _value, msg.value);
        events.emitGladiatorBattleSpectatorBetPlaced(_battleId, msg.sender, _willCreatorWin, _value, _isGold);
    }

    function removeSpectatorBetFromGladiatorBattle(
        uint256 _battleId
    ) external onlyHuman whenNotPaused {
        gladiatorBattleSpectators.removeBet(msg.sender, _battleId);
        events.emitGladiatorBattleSpectatorBetRemoved(_battleId, msg.sender);
    }

    function requestSpectatorRewardForGladiatorBattle(
        uint256 _battleId
    ) external onlyHuman whenNotPaused {
        (uint256 _reward, bool _isGold) = gladiatorBattleSpectators.requestReward(msg.sender, _battleId);
        events.emitGladiatorBattleSpectatorRewardPaidOut(_battleId, msg.sender, _reward, _isGold);
    }

    // UPDATE CONTRACT

    function setInternalDependencies(address[] _newDependencies) public onlyOwner {
        super.setInternalDependencies(_newDependencies);

        battleController = BattleController(_newDependencies[0]);
        gladiatorBattle = GladiatorBattle(_newDependencies[1]);
        gladiatorBattleSpectators = GladiatorBattleSpectators(_newDependencies[2]);
        getter = Getter(_newDependencies[3]);
        events = Events(_newDependencies[4]);
    }
}
