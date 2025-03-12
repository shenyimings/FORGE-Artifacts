pragma solidity 0.4.25;

import "../../Common/Upgradable.sol";
import "../../Common/Random.sol";
import "../../Battle.sol";
import "../../Gold/Gold.sol";
import "../../Getter.sol";
import "../../Treasury.sol";
import "./GladiatorBattleStorage.sol";
import "../Spectators/GladiatorBattleSpectatorsStorage.sol";
import "../../Common/SafeMath256.sol";

/* solium-disable operator-whitespace */

contract GladiatorBattle is Upgradable {
    using SafeMath256 for uint256;

    Battle battle;
    Random random;
    Gold goldTokens;
    Getter getter;
    Treasury treasury;
    GladiatorBattleStorage _storage_;
    GladiatorBattleSpectatorsStorage spectatorsStorage;

    uint8 constant MAX_TACTICS_PERCENTAGE = 80;
    uint8 constant MIN_TACTICS_PERCENTAGE = 20;
    uint8 constant MAX_DRAGON_STRENGTH_PERCENTAGE = 120;
    uint8 constant PERCENTAGE = 100;
    uint256 AUTO_SELECT_TIME = 6000; // in blocks
    uint256 INTERVAL_FOR_NEW_BLOCK = 1000; // in blocks

    function() external payable {}

    function _safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        return b > a ? 0 : a.sub(b);
    }

    function _payForBet(
        uint256 _value,
        bool _isGold,
        uint256 _bet
    ) internal {
        if (_isGold) {
            require(_value == 0, "specify isGold as false to send eth");
            goldTokens.remoteTransfer(address(_storage_), _bet);
        } else {
            require(_value == _bet, "wrong eth amount");
            address(_storage_).transfer(_value);
        }
    }

    function _validateChallengeId(uint256 _challengeId) internal view {
        require(
            _challengeId > 0 &&
            _challengeId < _storage_.challengesAmount(),
            "wrong challenge id"
        );
    }

    function _validateTactics(uint8[2] _tactics) internal pure {
        require(
            _tactics[0] >= MIN_TACTICS_PERCENTAGE &&
            _tactics[0] <= MAX_TACTICS_PERCENTAGE &&
            _tactics[1] >= MIN_TACTICS_PERCENTAGE &&
            _tactics[1] <= MAX_TACTICS_PERCENTAGE,
            "tactics value must be between 20 and 80"
        );
    }

    function _checkDragonAvailability(address _user, uint256 _dragonId) internal view {
        require(getter.isDragonOwner(_user, _dragonId), "not a dragon owner");
        require(!getter.isDragonOnSale(_dragonId), "dragon is on sale");
        require(!getter.isBreedingOnSale(_dragonId), "dragon is on breeding sale");
        require(!isDragonChallenging(_dragonId), "this dragon has already applied");
    }

    function _checkTheBattleHasNotOccurred(uint256 _challengeId) internal view {
        require(!_storage_.battleOccurred(_challengeId), "the battle has already occurred");
    }

    function _checkTheChallengeIsNotCancelled(uint256 _id) internal view {
        require(!_storage_.challengeCancelled(_id), "the challenge is cancelled");
    }

    function _checkTheOpponentIsNotSelected(uint256 _id) internal view {
        require(!_isOpponentSelected(_id), "opponent already selected");
    }

    function _checkThatTimeHasCome(uint256 _blockNumber) internal view {
        require(_blockNumber <= block.number, "time has not yet come");
    }

    function _checkChallengeCreator(uint256 _id, address _user) internal view {
        (address _creator, ) = _getCreator(_id);
        require(_creator == _user, "not a challenge creator");
    }

    function _checkForApplicants(uint256 _id) internal view {
        require(_getChallengeApplicantsAmount(_id) > 0, "no applicants");
    }

    function _compareApplicantsArrays(uint256 _challengeId, bytes32 _hash) internal view {
        uint256[] memory _applicants = _storage_.getChallengeApplicants(_challengeId);
        require(keccak256(abi.encode(_applicants)) == _hash, "wrong applicants array");
    }

    function _compareDragonStrength(uint256 _challengeId, uint256 _applicantId) internal view {
        ( , uint256 _dragonId) = _getCreator(_challengeId);
        uint256 _strength = getter.getDragonStrength(_dragonId);
        uint256 _applicantStrength = getter.getDragonStrength(_applicantId);
        uint256 _maxStrength = _strength.mul(MAX_DRAGON_STRENGTH_PERCENTAGE).div(PERCENTAGE); // +20%
        require(_applicantStrength <= _maxStrength, "too strong dragon");
    }

    function _setChallengeCompensation(
        uint256 _challengeId,
        uint256 _bet,
        uint256 _applicantsAmount
    ) internal {
        // 30% of a bet
        _storage_.setCompensation(_challengeId, _bet.mul(3).div(10).div(_applicantsAmount));
    }

    function _isOpponentSelected(uint256 _challengeId) internal view returns (bool) {
        ( , uint256 _dragonId) = _getOpponent(_challengeId);
        return _dragonId != 0;
    }

    function _getChallengeApplicantsAmount(
        uint256 _challengeId
    ) internal view returns (uint256) {
        return _storage_.challengeApplicantsAmount(_challengeId);
    }

    function _getUserApplicationIndex(
        address _user,
        uint256 _challengeId
    ) internal view returns (uint256, bool, uint256) {
        return _storage_.userApplicationIndex(_user, _challengeId);
    }

    function _getChallenge(
        uint256 _id
    ) internal view returns (bool, uint256, uint256) {
        return _storage_.challenges(_id);
    }

    function _getCompensation(
        uint256 _id
    ) internal view returns (uint256) {
        return _storage_.challengeCompensation(_id);
    }

    function _getDragonApplication(
        uint256 _id
    ) internal view returns (uint256, uint8[2], address) {
        return _storage_.getDragonApplication(_id);
    }

    function _getBattleBlockNumber(
        uint256 _id
    ) internal view returns (uint256) {
        return _storage_.battleBlockNumber(_id);
    }

    function _getCreator(
        uint256 _id
    ) internal view returns (address, uint256) {
        return _storage_.creator(_id);
    }

    function _getOpponent(
        uint256 _id
    ) internal view returns (address, uint256) {
        return _storage_.opponent(_id);
    }

    function _getSpectatorsBetsValue(
        uint256 _challengeId,
        bool _onCreator
    ) internal view returns (uint256) {
        return spectatorsStorage.challengeBetsValue(_challengeId, _onCreator);
    }

    function isDragonChallenging(uint256 _dragonId) public view returns (bool) {
        (uint256 _challengeId, , ) = _getDragonApplication(_dragonId);
        if (_challengeId != 0) {
            if (_storage_.challengeCancelled(_challengeId)) {
                return false;
            }
            ( , uint256 _owner) = _getCreator(_challengeId);
            ( , uint256 _opponent) = _getOpponent(_challengeId);
            bool _isParticipant = (_dragonId == _owner) || (_dragonId == _opponent);

            if (_isParticipant) {
                return !_storage_.battleOccurred(_challengeId);
            }
            return !_isOpponentSelected(_challengeId);
        }
        return false;
    }

    function create(
        address _user,
        uint256 _dragonId,
        uint8[2] _tactics,
        bool _isGold,
        uint256 _bet,
        uint16 _counter,
        uint256 _value // in eth
    ) external onlyController returns (uint256 challengeId) {
        _validateTactics(_tactics);
        _checkDragonAvailability(_user, _dragonId);
        require(_counter >= 5, "too few blocks");

        _payForBet(_value, _isGold, _bet);

        challengeId = _storage_.create(_isGold, _bet, _counter);
        _storage_.addUserChallenge(_user, challengeId);
        _storage_.setCreator(challengeId, _user, _dragonId);
        _storage_.setDragonApplication(_dragonId, challengeId, _tactics, _user);
    }

    function apply(
        uint256 _challengeId,
        address _user,
        uint256 _dragonId,
        uint8[2] _tactics,
        uint256 _value // in eth
    ) external onlyController {
        _validateChallengeId(_challengeId);
        _validateTactics(_tactics);
        _checkTheBattleHasNotOccurred(_challengeId);
        _checkTheChallengeIsNotCancelled(_challengeId);
        _checkTheOpponentIsNotSelected(_challengeId);
        _checkDragonAvailability(_user, _dragonId);
        _compareDragonStrength(_challengeId, _dragonId);
        ( , bool _exist, ) = _getUserApplicationIndex(_user, _challengeId);
        require(!_exist, "you have already applied");

        (bool _isGold, uint256 _bet, ) = _getChallenge(_challengeId);

        _payForBet(_value, _isGold, _bet);

        _storage_.addUserApplication(_user, _challengeId, _dragonId);
        _storage_.setDragonApplication(_dragonId, _challengeId, _tactics, _user);
        _storage_.addChallengeApplicant(_challengeId, _dragonId);

        // if it's the first applicant then set auto select block
        if (_getChallengeApplicantsAmount(_challengeId) == 1) {
            _storage_.setAutoSelectBlock(_challengeId, block.number.add(AUTO_SELECT_TIME));
        }
    }

    function chooseOpponent(
        address _user,
        uint256 _challengeId,
        uint256 _applicantId,
        bytes32 _applicantsHash
    ) external onlyController {
        _validateChallengeId(_challengeId);
        _checkChallengeCreator(_challengeId, _user);
        _compareApplicantsArrays(_challengeId, _applicantsHash);
        _selectOpponent(_challengeId, _applicantId);
    }

    function autoSelectOpponent(
        uint256 _challengeId,
        bytes32 _applicantsHash
    ) external onlyController returns (uint256 applicantId) {
        _validateChallengeId(_challengeId);
        _compareApplicantsArrays(_challengeId, _applicantsHash);
        uint256 _autoSelectBlock = _storage_.autoSelectBlock(_challengeId);
        require(_autoSelectBlock != 0, "no auto select");
        _checkThatTimeHasCome(_autoSelectBlock);

        _checkForApplicants(_challengeId);

        uint256 _applicantsAmount = _getChallengeApplicantsAmount(_challengeId);
        uint256 _index = random.random(2**256 - 1) % _applicantsAmount;
        applicantId = _storage_.challengeApplicants(_challengeId, _index);

        _selectOpponent(_challengeId, applicantId);
    }

    function _selectOpponent(uint256 _challengeId, uint256 _dragonId) internal {
        _checkTheChallengeIsNotCancelled(_challengeId);
        _checkTheOpponentIsNotSelected(_challengeId);

        (
            uint256 _dragonChallengeId, ,
            address _opponentUser
        ) = _getDragonApplication(_dragonId);
        ( , uint256 _creatorDragonId) = _getCreator(_challengeId);

        require(_dragonChallengeId == _challengeId, "wrong opponent");
        require(_creatorDragonId != _dragonId, "the same dragon");

        _storage_.setOpponent(_challengeId, _opponentUser, _dragonId);

        ( , uint256 _bet, uint256 _counter) = _getChallenge(_challengeId);
        _storage_.setBattleBlockNumber(_challengeId, block.number.add(_counter));

        _storage_.addUserChallenge(_opponentUser, _challengeId);
        _storage_.removeUserApplication(_opponentUser, _challengeId);

        // if there are more applicants than one just selected then set challenge compensation
        uint256 _applicantsAmount = _getChallengeApplicantsAmount(_challengeId);
        if (_applicantsAmount > 1) {
            uint256 _otherApplicants = _applicantsAmount.sub(1);
            _setChallengeCompensation(_challengeId, _bet, _otherApplicants);
        }
    }

    function _checkBattleBlockNumber(uint256 _blockNumber) internal view {
        require(_blockNumber != 0, "opponent is not selected");
        _checkThatTimeHasCome(_blockNumber);
    }

    function _checkBattlePossibilityAndGenerateRandom(uint256 _challengeId) internal view returns (uint256) {
        uint256 _blockNumber = _getBattleBlockNumber(_challengeId);
        _checkBattleBlockNumber(_blockNumber);
        require(_blockNumber >= _safeSub(block.number, 256), "time has passed");
        _checkTheBattleHasNotOccurred(_challengeId);
        _checkTheChallengeIsNotCancelled(_challengeId);

        return random.randomOfBlock(2**256 - 1, _blockNumber);
    }

    function _payReward(uint256 _challengeId) internal returns (uint256 reward, bool isGold) {
        uint8 _factor = _getCompensation(_challengeId) > 0 ? 17 : 20;
        uint256 _bet;
        (isGold, _bet, ) = _getChallenge(_challengeId);
        ( , uint256 _creatorId) = _getCreator(_challengeId);
        (address _winner, uint256 _winnerId) = _storage_.winner(_challengeId);

        reward = _bet.mul(_factor).div(10);
        _storage_.payOut(
            _winner,
            isGold,
            reward
        ); // 30% of bet to applicants

        bool _didCreatorWin = _creatorId == _winnerId;
        uint256 _winnerBetsValue = _getSpectatorsBetsValue(_challengeId, _didCreatorWin);
        uint256 _opponentBetsValue = _getSpectatorsBetsValue(_challengeId, !_didCreatorWin);
        if (_opponentBetsValue > 0 && _winnerBetsValue > 0) {
            uint256 _rewardFromSpectatorsBets = _opponentBetsValue.mul(15).div(100); // 15%

            uint256 _challengeBalance = spectatorsStorage.challengeBalance(_challengeId);
            require(_challengeBalance >= _rewardFromSpectatorsBets, "not enough coins, something went wrong");

            spectatorsStorage.payOut(_winner, isGold, _rewardFromSpectatorsBets);

            _challengeBalance = _challengeBalance.sub(_rewardFromSpectatorsBets);
            spectatorsStorage.setChallengeBalance(_challengeId, _challengeBalance);

            reward = reward.add(_rewardFromSpectatorsBets);
        }
    }

    function _setWinner(uint256 _challengeId, uint256 _dragonId) internal {
        ( , , address _user) = _getDragonApplication(_dragonId);
        _storage_.setWinner(_challengeId, _user, _dragonId);
    }

    function start(
        uint256 _challengeId
    ) external onlyController returns (
        uint256 seed,
        uint256 battleId,
        uint256 reward,
        bool isGold
    ) {
        _validateChallengeId(_challengeId);
        seed = _checkBattlePossibilityAndGenerateRandom(_challengeId);

        ( , uint256 _firstDragonId) = _getCreator(_challengeId);
        ( , uint256 _secondDragonId) = _getOpponent(_challengeId);

        ( , uint8[2] memory _firstTactics, ) = _getDragonApplication(_firstDragonId);
        ( , uint8[2] memory _secondTactics, ) = _getDragonApplication(_secondDragonId);

        uint256[2] memory winnerLooserIds;
        (
            winnerLooserIds, , , , , battleId
        ) = battle.start(
            _firstDragonId,
            _secondDragonId,
            _firstTactics,
            _secondTactics,
            seed,
            true
        );

        _setWinner(_challengeId, winnerLooserIds[0]);

        _storage_.setBattleOccurred(_challengeId);
        _storage_.setChallengeBattleId(_challengeId, battleId);

        (reward, isGold) = _payReward(_challengeId);
    }

    function cancel(
        address _user,
        uint256 _challengeId,
        bytes32 _applicantsHash
    ) external onlyController {
        _validateChallengeId(_challengeId);
        _checkChallengeCreator(_challengeId, _user);
        _checkTheOpponentIsNotSelected(_challengeId);
        _checkTheChallengeIsNotCancelled(_challengeId);
        _compareApplicantsArrays(_challengeId, _applicantsHash);

        (bool _isGold, uint256 _value /* bet */, ) = _getChallenge(_challengeId);
        uint256 _applicantsAmount = _getChallengeApplicantsAmount(_challengeId);
        // if there are opponents then set challenge compensation
        if (_applicantsAmount > 0) {
            _setChallengeCompensation(_challengeId, _value, _applicantsAmount); // 30% to applicants
            _value = _value.mul(7).div(10); // 70% to creator
        }
        _storage_.payOut(_user, _isGold, _value);
        _storage_.setChallengeCancelled(_challengeId);
    }

    function returnBet(address _user, uint256 _challengeId) external onlyController {
        _validateChallengeId(_challengeId);
        ( , bool _exist, uint256 _dragonId) = _getUserApplicationIndex(_user, _challengeId);
        require(_exist, "wrong challenge");

        (bool _isGold, uint256 _bet, ) = _getChallenge(_challengeId);
        uint256 _compensation = _getCompensation(_challengeId);
        uint256 _value = _bet.add(_compensation);
        _storage_.payOut(_user, _isGold, _value);
        _storage_.removeDragonApplication(_dragonId, _challengeId);
        _storage_.removeUserApplication(_user, _challengeId);

        // if there are no more applicants then reset auto select block
        if (_getChallengeApplicantsAmount(_challengeId) == 0) {
            _storage_.setAutoSelectBlock(_challengeId, 0);
        }
    }

    function addTimeForOpponentSelect(
        address _user,
        uint256 _challengeId
    ) external onlyController returns (uint256 newAutoSelectBlock) {
        _validateChallengeId(_challengeId);
        _checkChallengeCreator(_challengeId, _user);
        _checkForApplicants(_challengeId);
        _checkTheOpponentIsNotSelected(_challengeId);
        _checkTheChallengeIsNotCancelled(_challengeId);
        uint256 _price = _storage_.getExtensionTimePrice(_challengeId);
         // take gold
        treasury.takeGold(_price);
         // update multiplier
        _storage_.setExtensionTimePrice(_challengeId, _price.mul(2));
        // update auto select block
        uint256 _autoSelectBlock = _storage_.autoSelectBlock(_challengeId);
        newAutoSelectBlock = _autoSelectBlock.add(AUTO_SELECT_TIME);
        _storage_.setAutoSelectBlock(_challengeId, newAutoSelectBlock);
    }

    function updateBattleBlockNumber(
        uint256 _challengeId
    ) external onlyController returns (uint256 newBattleBlockNumber) {
        _validateChallengeId(_challengeId);
        _checkTheBattleHasNotOccurred(_challengeId);
        _checkTheChallengeIsNotCancelled(_challengeId);
        uint256 _blockNumber = _getBattleBlockNumber(_challengeId);
        _checkBattleBlockNumber(_blockNumber);
        require(_blockNumber < _safeSub(block.number, 256), "you can start a battle");

        newBattleBlockNumber = block.number.add(INTERVAL_FOR_NEW_BLOCK);
        _storage_.setBattleBlockNumber(_challengeId, newBattleBlockNumber);
    }

    // UPDATE CONTRACT

    function setInternalDependencies(address[] _newDependencies) public onlyOwner {
        super.setInternalDependencies(_newDependencies);

        battle = Battle(_newDependencies[0]);
        random = Random(_newDependencies[1]);
        goldTokens = Gold(_newDependencies[2]);
        getter = Getter(_newDependencies[3]);
        treasury = Treasury(_newDependencies[4]);
        _storage_ = GladiatorBattleStorage(_newDependencies[5]);
        spectatorsStorage = GladiatorBattleSpectatorsStorage(_newDependencies[6]);
    }
}
