pragma solidity 0.4.25;


import "./Common/Upgradable.sol";
import "./Common/Random.sol";
import "./Core.sol";
import "./Battle.sol";
import "./Treasury.sol";
import "./Getter.sol";
import "./Common/SafeMath8.sol";
import "./Common/SafeMath16.sol";
import "./Common/SafeMath32.sol";
import "./Common/SafeMath256.sol";

/* solium-disable operator-whitespace */

contract BattleController is Upgradable {
    using SafeMath8 for uint8;
    using SafeMath16 for uint16;
    using SafeMath32 for uint32;
    using SafeMath256 for uint256;

    Core core;
    Battle battle;
    Treasury treasury;
    Getter getter;
    Random random;

    // stores date to which dragon is untouchable as opponent for the battle
    mapping (uint256 => uint256) lastBattleDate;

    uint8 constant MAX_PERCENTAGE = 100;
    uint8 constant MIN_HEALTH_PERCENTAGE = 50;
    uint8 constant MAX_TACTICS_PERCENTAGE = 80;
    uint8 constant MIN_TACTICS_PERCENTAGE = 20;
    uint8 constant PERCENT_MULTIPLIER = 100;
    uint8 constant DRAGON_STRENGTH_DIFFERENCE_PERCENTAGE = 10;
    uint32 constant MAX_GOLD_REWARD_MULTIPLIER = 10000000;

    uint256 constant GOLD_REWARD_MULTIPLIER = 10 ** 18;

    function _min(uint256 lth, uint256 rth) internal pure returns (uint256) {
        return lth > rth ? rth : lth;
    }

    function _isTouchable(uint256 _id) internal view returns (bool) {
        uint32 _regenerationTime = core.getDragonFullRegenerationTime(_id);
        return lastBattleDate[_id].add(_regenerationTime.mul(4)) < now; // solium-disable-line security/no-block-members
    }

    function _checkBattlePossibility(
        address _sender,
        uint256 _id,
        uint256 _opponentId,
        uint8[2] _tactics
    ) internal view {
        require(getter.isDragonOwner(_sender, _id), "not an owner");
        require(!getter.isDragonOwner(_sender, _opponentId), "can't be owner of opponent dragon");
        require(!getter.isDragonOwner(address(0), _opponentId), "opponent dragon has no owner");

        require(!getter.isDragonInGladiatorBattle(_id), "your dragon participates in gladiator battle");
        require(!getter.isDragonInGladiatorBattle(_opponentId), "opponent dragon participates in gladiator battle");

        require(_isTouchable(_opponentId), "opponent dragon is untouchable");

        require(
            _tactics[0] >= MIN_TACTICS_PERCENTAGE &&
            _tactics[0] <= MAX_TACTICS_PERCENTAGE &&
            _tactics[1] >= MIN_TACTICS_PERCENTAGE &&
            _tactics[1] <= MAX_TACTICS_PERCENTAGE,
            "tactics value must be between 20 and 80"
        );

        uint8 _attackerHealthPercentage;
        uint8 _attackerManaPercentage;
        ( , , _attackerHealthPercentage, _attackerManaPercentage) = getter.getDragonCurrentHealthAndMana(_id);
        require(
            _attackerHealthPercentage >= MIN_HEALTH_PERCENTAGE,
            "dragon's health less than 50%"
        );
        uint8 _opponentHealthPercentage;
        uint8 _opponentManaPercentage;
        ( , , _opponentHealthPercentage, _opponentManaPercentage) = getter.getDragonCurrentHealthAndMana(_opponentId);
        require(
            _opponentHealthPercentage == MAX_PERCENTAGE &&
            _opponentManaPercentage == MAX_PERCENTAGE,
            "opponent health and/or mana is not full"
        );
    }

    function startBattle(
        address _sender,
        uint256 _id,
        uint256 _opponentId,
        uint8[2] _tactics
    ) external onlyController returns (
        uint256 battleId,
        uint256 seed,
        uint256[2] winnerLooserIds
    ) {
        _checkBattlePossibility(_sender, _id, _opponentId, _tactics);

        seed = random.random(2**256 - 1);

        uint32 _winnerHealth;
        uint32 _winnerMana;
        uint32 _looserHealth;
        uint32 _looserMana;

        (
            winnerLooserIds,
            _winnerHealth, _winnerMana,
            _looserHealth, _looserMana,
            battleId
        ) = battle.start(
            _id,
            _opponentId,
            _tactics,
            [0, 0],
            seed,
            false
        );

        core.setDragonRemainingHealthAndMana(winnerLooserIds[0], _winnerHealth, _winnerMana);
        core.setDragonRemainingHealthAndMana(winnerLooserIds[1], _looserHealth, _looserMana);

        core.increaseDragonWins(winnerLooserIds[0]);
        core.increaseDragonDefeats(winnerLooserIds[1]);

        lastBattleDate[_opponentId] = now; // solium-disable-line security/no-block-members

        _payBattleRewards(
            _sender,
            _id,
            _opponentId,
            winnerLooserIds[0]
        );
    }

    function _payBattleRewards(
        address _sender,
        uint256 _id,
        uint256 _opponentId,
        uint256 _winnerId
    ) internal {
        uint32 _strength = getter.getDragonStrength(_id);
        uint32 _opponentStrength = getter.getDragonStrength(_opponentId);
        bool _isAttackerWinner = _id == _winnerId;

        uint256 _xpFactor = _calculateExperience(_isAttackerWinner, _strength, _opponentStrength);
        core.increaseDragonExperience(_winnerId, _xpFactor);

        if (_isAttackerWinner) {
            uint256 _factor = _calculateGoldRewardFactor(_strength, _opponentStrength);
            _payGoldReward(_sender, _id, _factor);
        }
    }

    function _calculateExperience(
        bool _isAttackerWinner,
        uint32 _attackerStrength,
        uint32 _opponentStrength
    ) internal pure returns (uint256) {

        uint8 _attackerFactor;
        uint256 _winnerStrength;
        uint256 _looserStrength;

        uint8 _degree;

        if (_isAttackerWinner) {
            _attackerFactor = 10;
            _winnerStrength = _attackerStrength;
            _looserStrength = _opponentStrength;
            _degree = _winnerStrength <= _looserStrength ? 2 : 5;
        } else {
            _attackerFactor = 5;
            _winnerStrength = _opponentStrength;
            _looserStrength = _attackerStrength;
            _degree = _winnerStrength <= _looserStrength ? 1 : 5;
        }

        uint256 _factor = _looserStrength.pow(_degree).mul(_attackerFactor).div(_winnerStrength.pow(_degree));

        if (_isAttackerWinner) {
            return _factor;
        }
        return _min(_factor, 10); // 1
    }

    function _calculateGoldRewardFactor(
        uint256 _winnerStrength,
        uint256 _looserStrength
    ) internal pure returns (uint256) {
        uint8 _degree = _winnerStrength <= _looserStrength ? 1 : 8;
        return _looserStrength.pow(_degree).mul(GOLD_REWARD_MULTIPLIER).div(_winnerStrength.pow(_degree));
    }

    function _getMaxGoldReward(
        uint256 _hatchingPrice,
        uint256 _dragonsAmount
    ) internal pure returns (uint256) {
        uint32 _factor;

        if (_dragonsAmount < 3000) _factor = 2000000; // Hydrogen Eon
        else if (_dragonsAmount < 6000) _factor = 1000000; // Helium Eon
        else if (_dragonsAmount < 9000) _factor = 500000; // Carbon Eon
        else if (_dragonsAmount < 12000) _factor = 250000; // Oxygen Eon
        else if (_dragonsAmount < 15000) _factor = 125000; // Silicon Eon
        else if (_dragonsAmount < 18000) _factor = 62500; // Titanium Eon
        else if (_dragonsAmount < 21000) _factor = 31250; // Silver Eon
        else _factor = 15625; // Gold Eon

        return _hatchingPrice.mul(_factor).div(MAX_GOLD_REWARD_MULTIPLIER);
    }

    function _payGoldReward(
        address _sender,
        uint256 _id,
        uint256 _factor
    ) internal {
        uint256 _goldRemain = treasury.remainingGold();
        uint256 _dragonsAmount = getter.getDragonsAmount();
        uint32 _coolness;
        (, , , , , , , _coolness) = getter.getDragonProfile(_id);
        uint256 _hatchingPrice = treasury.hatchingPrice();
        // dragon coolness is multyplied by 100
        uint256 _value = _goldRemain.mul(_coolness).mul(10).div(_dragonsAmount.pow(2)).div(100);
        _value = _value.mul(_factor).div(GOLD_REWARD_MULTIPLIER);

        uint256 _maxReward = _getMaxGoldReward(_hatchingPrice, _dragonsAmount);
        if (_value > _maxReward) _value = _maxReward;
        if (_value > _goldRemain) _value = _goldRemain;
        treasury.giveGold(_sender, _value);
    }

    struct Opponent {
        uint256 id;
        uint256 timestamp;
        uint32 strength;
    }

    function _iterateTimestampIndex(uint8 _index) internal pure returns (uint8) {
        return _index < 5 ? _index.add(1) : 0;
    }

    function _getPercentOfValue(uint32 _value, uint8 _percent) internal pure returns (uint32) {
        return _value.mul(_percent).div(PERCENT_MULTIPLIER);
    }

    function matchOpponents(uint256 _attackerId) external view returns (uint256[6]) {
        uint32 _attackerStrength = getter.getDragonStrength(_attackerId);
        uint32 _strengthDiff = _getPercentOfValue(_attackerStrength, DRAGON_STRENGTH_DIFFERENCE_PERCENTAGE);
        uint32 _minStrength = _attackerStrength.sub(_strengthDiff);
        uint32 _maxStrength = _attackerStrength.add(_strengthDiff);
        uint32 _strength;
        uint256 _timestamp; // usually the date of the last battle
        uint8 _timestampIndex;
        uint8 _healthPercentage;
        uint8 _manaPercentage;

        address _owner = getter.ownerOfDragon(_attackerId);

        Opponent[6] memory _opponents;
        _opponents[0].timestamp =
        _opponents[1].timestamp =
        _opponents[2].timestamp =
        _opponents[3].timestamp =
        _opponents[4].timestamp =
        _opponents[5].timestamp = now; // solium-disable-line security/no-block-members

        for (uint256 _id = 1; _id <= getter.getDragonsAmount(); _id++) { // no dragon with id = 0

            if (
                _attackerId != _id
                && !getter.isDragonOwner(_owner, _id)
                && !getter.isDragonInGladiatorBattle(_id)
                && _isTouchable(_id)
            ) {
                _strength = getter.getDragonStrength(_id);
                if (_strength >= _minStrength && _strength <= _maxStrength) {

                    ( , , _healthPercentage, _manaPercentage) = getter.getDragonCurrentHealthAndMana(_id);
                    if (_healthPercentage == MAX_PERCENTAGE && _manaPercentage == MAX_PERCENTAGE) {

                        (_timestamp, , , , ) = getter.getDragonHealthAndMana(_id);
                        if (_timestamp < _opponents[_timestampIndex].timestamp) {

                            _opponents[_timestampIndex] = Opponent(_id, _timestamp, _strength);
                            _timestampIndex = _iterateTimestampIndex(_timestampIndex);
                        }
                    }
                }
            }
        }
        return [
            _opponents[0].id,
            _opponents[1].id,
            _opponents[2].id,
            _opponents[3].id,
            _opponents[4].id,
            _opponents[5].id
        ];
    }

    function resetDragonBuffs(uint256 _id) external onlyController {
        core.resetDragonBuffs(_id);
    }

    // UPDATE CONTRACT

    function setInternalDependencies(address[] _newDependencies) public onlyOwner {
        super.setInternalDependencies(_newDependencies);

        core = Core(_newDependencies[0]);
        battle = Battle(_newDependencies[1]);
        treasury = Treasury(_newDependencies[2]);
        getter = Getter(_newDependencies[3]);
        random = Random(_newDependencies[4]);
    }
}
