pragma solidity 0.4.25;

import "../../Common/Upgradable.sol";
import "../../Gold/Gold.sol";
import "../../Common/SafeMath256.sol";

/* solium-disable operator-whitespace */

contract GladiatorBattleSpectatorsStorage is Upgradable {
    using SafeMath256 for uint256;

    Gold goldTokens;

    struct Bet {
        address user;
        uint256 challengeId;
        bool willCreatorWin;
        uint256 value;
        bool active;
    }

    mapping (uint256 => uint256[]) challengeBets;
    mapping (uint256 => mapping (uint256 => uint256)) public challengeBetIndex;
    mapping (uint256 => mapping (bool => uint256)) public challengeBetsAmount;
    mapping (uint256 => mapping (bool => uint256)) public challengeBetsValue;
    mapping (uint256 => uint256) public challengeWinningBetsAmount;
    mapping (uint256 => uint256) public challengeBalance;
    mapping (address => uint256[]) userChallenges;
    mapping (address => mapping (uint256 => uint256)) public userChallengeIndex;
    mapping (address => mapping (uint256 => uint256)) public userChallengeBetId;

    Bet[] public allBets;

    constructor() public {
        allBets.length = 1;
    }

    function() external payable {}

    function payOut(address _user, bool _isGold, uint256 _value) external onlyController {
        if (_isGold) {
            goldTokens.transfer(_user, _value);
        } else {
            _user.transfer(_value);
        }
    }

    function addBet(
        address _user,
        uint256 _challengeId,
        bool _willCreatorWin,
        uint256 _value
    ) external onlyController returns (uint256 id) {
        id = allBets.length;
        allBets.push(Bet(_user, _challengeId, _willCreatorWin, _value, true));
    }

    function addChallengeBet(
        uint256 _challengeId,
        uint256 _betId
    ) external onlyController returns (uint256 index) {
        index = challengeBets[_challengeId].length;
        challengeBets[_challengeId].push(_betId);
        challengeBetIndex[_challengeId][_betId] = index;
    }

    function addUserChallenge(
        address _user,
        uint256 _challengeId,
        uint256 _betId
    ) external onlyController {
        uint256 _index = userChallenges[_user].length;
        userChallenges[_user].push(_challengeId);
        userChallengeIndex[_user][_challengeId] = _index;
        userChallengeBetId[_user][_challengeId] = _betId;
    }

    function deactivateBet(uint256 _betId) external onlyController {
        allBets[_betId].active = false;
    }

    function removeChallengeBet(
        uint256 _challengeId,
        uint256 _betId
    ) external onlyController {
        uint256 _index = challengeBetIndex[_challengeId][_betId];
        uint256 _lastIndex = challengeBets[_challengeId].length.sub(1);
        uint256 _lastItem = challengeBets[_challengeId][_lastIndex];

        challengeBets[_challengeId][_index] = _lastItem;
        challengeBets[_challengeId][_lastIndex] = 0;

        challengeBets[_challengeId].length--;
        delete challengeBetIndex[_challengeId][_betId];
        challengeBetIndex[_challengeId][_lastItem] = _index;
    }

    function removeUserChallenge(
        address _user,
        uint256 _challengeId
    ) external onlyController {
        uint256 _index = userChallengeIndex[_user][_challengeId];
        uint256 _lastIndex = userChallenges[_user].length.sub(1);
        uint256 _lastItem = userChallenges[_user][_lastIndex];

        userChallenges[_user][_index] = _lastItem;
        userChallenges[_user][_lastIndex] = 0;

        userChallenges[_user].length--;
        delete userChallengeIndex[_user][_challengeId];
        delete userChallengeBetId[_user][_challengeId];
        userChallengeIndex[_user][_lastItem] = _index;
    }

    function setChallengeBetsAmount(
        uint256 _challengeId,
        bool _willCreatorWin,
        uint256 _value
    ) external onlyController {
        challengeBetsAmount[_challengeId][_willCreatorWin] = _value;
    }

    function setChallengeWinningBetsAmount(
        uint256 _challengeId,
        uint256 _value
    ) external onlyController {
        challengeWinningBetsAmount[_challengeId] = _value;
    }

    function setChallengeBetsValue(
        uint256 _challengeId,
        bool _willCreatorWin,
        uint256 _value
    ) external onlyController {
        challengeBetsValue[_challengeId][_willCreatorWin] = _value;
    }

    function setChallengeBalance(
        uint256 _challengeId,
        uint256 _value
    ) external onlyController {
        challengeBalance[_challengeId] = _value;
    }

    // GETTERS

    function betsAmount() external view returns (uint256) {
        return allBets.length;
    }

    function getChallengeBetsAmount(
        uint256 _challengeId
    ) external view returns (
        uint256 onCreator,
        uint256 onOpponent
    ) {
        return (
            challengeBetsAmount[_challengeId][true],
            challengeBetsAmount[_challengeId][false]
        );
    }

    function getChallengeBetsValue(
        uint256 _challengeId
    ) external view returns (
        uint256 onCreator,
        uint256 onOpponent
    ) {
        return (
            challengeBetsValue[_challengeId][true],
            challengeBetsValue[_challengeId][false]
        );
    }

    function getUserBet(
        address _user,
        uint256 _challengeId
    ) external view returns (
        uint256 betId,
        bool willCreatorWin,
        uint256 value,
        bool active
    ) {
        uint256 _betId = userChallengeBetId[_user][_challengeId];
        require(_betId > 0, "bet doesn't exist");
        return (
            _betId,
            allBets[_betId].willCreatorWin,
            allBets[_betId].value,
            allBets[_betId].active
        );
    }

    function getChallengeBets(
        uint256 _challengeId
    ) external view returns (uint256[]) {
        return challengeBets[_challengeId];
    }

    function getUserChallenges(
        address _user
    ) external view returns (uint256[]) {
        return userChallenges[_user];
    }

    // UPDATE CONTRACT

    function setInternalDependencies(address[] _newDependencies) public onlyOwner {
        super.setInternalDependencies(_newDependencies);

        goldTokens = Gold(_newDependencies[0]);
    }
}
