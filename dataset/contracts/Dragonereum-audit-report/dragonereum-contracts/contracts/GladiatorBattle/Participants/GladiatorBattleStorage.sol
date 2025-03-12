pragma solidity 0.4.25;

import "../../Common/Upgradable.sol";
import "../../Gold/Gold.sol";
import "../../Common/SafeMath256.sol";

/* solium-disable operator-whitespace */

contract GladiatorBattleStorage is Upgradable {
    using SafeMath256 for uint256;

    Gold goldTokens;

    uint256 EXTENSION_TIME_START_PRICE; // in gold

    struct Participant { // one of 2 participants in the challenge
        address user;
        uint256 dragonId;
    }

    struct Challenge {
        bool isGold; // false - ether, true - gold
        uint256 bet;
        uint16 counter; // in blocks
    }

    Challenge[] public challenges;

    mapping (uint256 => Participant) public creator; // challenge creator
    mapping (uint256 => Participant) public opponent; // opponent
    mapping (uint256 => Participant) public winner; // challenge winner

    // the number of block after which the battle may be started
    mapping (uint256 => uint256) public battleBlockNumber;
    // has the battle occurred?
    mapping (uint256 => bool) public battleOccurred;
    // the number of block after which the opponent may be auto selected
    mapping (uint256 => uint256) public autoSelectBlock;
    // is the challenge cancelled?
    mapping (uint256 => bool) public challengeCancelled;
    // amount of compensation for the challenge
    mapping (uint256 => uint256) public challengeCompensation;
    // price of extension time to select an opponent
    mapping (uint256 => uint256) extensionTimePrice;

    struct DragonApplication {
        uint256 challengeId;
        uint8[2] tactics;
        address owner;
    }

    struct UserApplication {
        uint256 index; // index if userApplications array
        bool exist;
        uint256 dragonId; // dragon id for current challenge
    }

    // array of challenges where user is a participant
    mapping (address => uint256[]) userChallenges;

    // array of dragon ids that applied for this challenge
    mapping (uint256 => uint256[]) public challengeApplicants;
    // index of dragon in challengeApplicants array
    mapping (uint256 => uint256) applicantIndex;

    // array of challenges for which the user has applied
    mapping (address => uint256[]) userApplications;
    // user application by user and challengeId
    mapping (address => mapping(uint256 => UserApplication)) public userApplicationIndex;
    mapping (uint256 => DragonApplication) dragonApplication;

    mapping (uint256 => uint256) challengeBattleId;


    constructor() public {
        challenges.length = 1; // to avoid some issues with 0
        EXTENSION_TIME_START_PRICE = 50 * (10 ** 18);
    }

    function() external payable {}

    function payOut(address _user, bool _isGold, uint256 _value) external onlyController {
        if (_isGold) {
            goldTokens.transfer(_user, _value);
        } else {
            _user.transfer(_value);
        }
    }

    function create(
        bool _isGold,
        uint256 _bet,
        uint16 _counter
    ) external onlyController returns (uint256 challengeId) {
        Challenge memory _challenge = Challenge({
            isGold: _isGold,
            bet: _bet,
            counter: _counter
        });
        challengeId = challenges.length;
        challenges.push(_challenge);
    }

    function addUserChallenge(address _user, uint256 _challengeId) external onlyController {
        userChallenges[_user].push(_challengeId);
    }

    function setCreator(
        uint256 _challengeId,
        address _user,
        uint256 _dragonId
    ) external onlyController {
        creator[_challengeId] = Participant(_user, _dragonId);
    }

    function setOpponent(
        uint256 _challengeId,
        address _user,
        uint256 _dragonId
    ) external onlyController {
        opponent[_challengeId] = Participant(_user, _dragonId);
    }

    function setWinner(
        uint256 _challengeId,
        address _user,
        uint256 _dragonId
    ) external onlyController {
        winner[_challengeId] = Participant(_user, _dragonId);
    }

    function setDragonApplication(
        uint256 _dragonId,
        uint256 _challengeId,
        uint8[2] _tactics,
        address _user
    ) external onlyController {
        dragonApplication[_dragonId] = DragonApplication(_challengeId, _tactics, _user);
    }

    function removeDragonApplication(
        uint256 _dragonId,
        uint256 _challengeId
    ) external onlyController {
        if (dragonApplication[_dragonId].challengeId == _challengeId) {
            uint256 _index = applicantIndex[_dragonId];
            uint256 _lastIndex = challengeApplicants[_challengeId].length.sub(1);
            uint256 _lastItem = challengeApplicants[_challengeId][_lastIndex];

            challengeApplicants[_challengeId][_index] = _lastItem;
            challengeApplicants[_challengeId][_lastIndex] = 0;

            challengeApplicants[_challengeId].length--;
            delete applicantIndex[_dragonId];
        }
        delete dragonApplication[_dragonId];
    }

    function addUserApplication(
        address _user,
        uint256 _challengeId,
        uint256 _dragonId
    ) external onlyController {
        uint256 _index = userApplications[_user].length;
        userApplications[_user].push(_challengeId);
        userApplicationIndex[_user][_challengeId] = UserApplication(_index, true, _dragonId);
    }

    function removeUserApplication(
        address _user,
        uint256 _challengeId
    ) external onlyController {
        uint256 _index = userApplicationIndex[_user][_challengeId].index;
        uint256 _lastIndex = userApplications[_user].length.sub(1);
        uint256 _lastItem = userApplications[_user][_lastIndex];

        userApplications[_user][_index] = _lastItem;
        userApplications[_user][_lastIndex] = 0;

        userApplications[_user].length--;
        delete userApplicationIndex[_user][_challengeId];
        userApplicationIndex[_user][_lastItem].index = _index;
    }

    function addChallengeApplicant(
        uint256 _challengeId,
        uint256 _dragonId
    ) external onlyController {
        uint256 _applicantIndex = challengeApplicants[_challengeId].length;
        challengeApplicants[_challengeId].push(_dragonId);
        applicantIndex[_dragonId] = _applicantIndex;
    }

    function setAutoSelectBlock(
        uint256 _challengeId,
        uint256 _number
    ) external onlyController {
        autoSelectBlock[_challengeId] = _number;
    }

    function setBattleBlockNumber(
        uint256 _challengeId,
        uint256 _number
    ) external onlyController {
        battleBlockNumber[_challengeId] = _number;
    }

    function setCompensation(
        uint256 _challengeId,
        uint256 _value
    ) external onlyController {
        challengeCompensation[_challengeId] = _value;
    }

    function setBattleOccurred(
        uint256 _challengeId
    ) external onlyController {
        battleOccurred[_challengeId] = true;
    }

    function setChallengeBattleId(
        uint256 _challengeId,
        uint256 _battleId
    ) external onlyController {
        challengeBattleId[_challengeId] = _battleId;
    }

    function setChallengeCancelled(
        uint256 _challengeId
    ) external onlyController {
        challengeCancelled[_challengeId] = true;
    }

    function setExtensionTimePrice(
        uint256 _challengeId,
        uint256 _value
    ) external onlyController {
        extensionTimePrice[_challengeId] = _value;
    }

    function setExtensionTimeStartPrice(
        uint256 _value
    ) external onlyController {
        EXTENSION_TIME_START_PRICE = _value;
    }

    // GETTERS

    function challengesAmount() external view returns (uint256) {
        return challenges.length;
    }

    function getUserChallenges(address _user) external view returns (uint256[]) {
        return userChallenges[_user];
    }

    function getChallengeApplicants(uint256 _challengeId) external view returns (uint256[]) {
        return challengeApplicants[_challengeId];
    }

    function challengeApplicantsAmount(uint256 _challengeId) external view returns (uint256) {
        return challengeApplicants[_challengeId].length;
    }

    function getDragonApplication(uint256 _dragonId) external view returns (uint256, uint8[2], address) {
        return (
            dragonApplication[_dragonId].challengeId,
            dragonApplication[_dragonId].tactics,
            dragonApplication[_dragonId].owner
        );
    }

    function getUserApplications(address _user) external view returns (uint256[]) {
        return userApplications[_user];
    }

    function getExtensionTimePrice(uint256 _challengeId) public view returns (uint256) {
        uint256 _price = extensionTimePrice[_challengeId];
        return _price != 0 ? _price : EXTENSION_TIME_START_PRICE;
    }

    function getChallengeParticipants(
        uint256 _challengeId
    ) external view returns (
        address firstUser,
        uint256 firstDragonId,
        address secondUser,
        uint256 secondDragonId,
        address winnerUser,
        uint256 winnerDragonId
    ) {
        firstUser = creator[_challengeId].user;
        firstDragonId = creator[_challengeId].dragonId;
        secondUser = opponent[_challengeId].user;
        secondDragonId = opponent[_challengeId].dragonId;
        winnerUser = winner[_challengeId].user;
        winnerDragonId = winner[_challengeId].dragonId;
    }

    function getChallengeDetails(
        uint256 _challengeId
    ) external view returns (
        bool isGold,
        uint256 bet,
        uint16 counter,
        uint256 blockNumber,
        bool active,
        uint256 opponentAutoSelectBlock,
        bool cancelled,
        uint256 compensation,
        uint256 selectionExtensionTimePrice,
        uint256 battleId
    ) {
        isGold = challenges[_challengeId].isGold;
        bet = challenges[_challengeId].bet;
        counter = challenges[_challengeId].counter;
        blockNumber = battleBlockNumber[_challengeId];
        active = !battleOccurred[_challengeId];
        opponentAutoSelectBlock = autoSelectBlock[_challengeId];
        cancelled = challengeCancelled[_challengeId];
        compensation = challengeCompensation[_challengeId];
        selectionExtensionTimePrice = getExtensionTimePrice(_challengeId);
        battleId = challengeBattleId[_challengeId];
    }

    // UPDATE CONTRACT

    function setInternalDependencies(address[] _newDependencies) public onlyOwner {
        super.setInternalDependencies(_newDependencies);

        goldTokens = Gold(_newDependencies[0]);
    }
}
