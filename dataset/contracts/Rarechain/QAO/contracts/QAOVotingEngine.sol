pragma solidity 0.8.1;

import "./QAOToken.sol";

contract QAOVotingEngine is Ownable {

    struct Vote {
        address creator;
        uint256 creationTimestamp;
        uint256 endTimestamp;
        uint256 votePositive;
        uint256 voteNegative;
        bool active;
        string heading;
        string description;
    }

    struct VoteAttendance {
        uint256 amount;
        uint256 timestamp; // if lockOption = 1, timestamp of the staking; if lockOption = 2 unlock timestamp
        uint8 lockOption; // 0 = no locking, 1 = locking until vote has ended, 2 = locking until timestamp has been reached
        bool position;
        bool withdrawn;
    }

    modifier validVote(uint256 voteId){
        require(voteId > 0 && voteId <= _voteCounter, "QAO Vote Engine: Not a valid vote id.");
        _;
    }

    event StartOfVote(uint256 voteId);
    event EndOfVote(uint256 voteId);

    /**** MEMBERS ********************************************* */

    uint256 public constant INIT_VOTE_AMOUNT = 1000000 ether;
    uint256 public constant END_VOTE_AMOUNT = 10000000 ether;
    uint256 private constant WEEK_IN_SECONDS = 604800;
    uint256 private constant DIV_ACCURACY = 1 ether;


    QAOToken private _qaoToken;
    uint256 private _voteCounter = 0;

    mapping(uint256 => Vote) private _idToVote;
    mapping(address => mapping (uint256 => VoteAttendance)) private _userToVoteToAttendance;

    mapping(uint256 => uint256) internal _weekToMultiplier;


    constructor(address qaoTokenAddr) {
        _qaoToken = QAOToken(qaoTokenAddr);
    }

    function quaToken() external view returns (address) {
        return address(_qaoToken);
    }

    function createVote(string calldata heading, string calldata description) external {
        require(_qaoToken.transferFrom(_msgSender(), address(this), INIT_VOTE_AMOUNT), 
                "QAO Voting Engine: Not enough token approved to engine to init a vote.");
        
        _voteCounter = _voteCounter + 1;
        _idToVote[_voteCounter] = Vote(_msgSender(), block.timestamp, 0, INIT_VOTE_AMOUNT, 0, true, heading, description);
        _userToVoteToAttendance[_msgSender()][_voteCounter] = VoteAttendance(INIT_VOTE_AMOUNT, block.timestamp, 1, true, false);
        emit StartOfVote(_voteCounter);
    }

    function vote(uint256 voteId, uint256 tokenAmount, uint256 lockWeeks, uint8 lockOption, bool position) external validVote(voteId) {

        // *** step 1 - pre-checks ***
        require(_idToVote[voteId].active, "QAO Voting Engine: Vote is not active.");

        require(_qaoToken.transferFrom(_msgSender(), address(this), tokenAmount), 
                "QAO Voting Engine: Not enough token approved to engine to submit the vote.");
        
        require(_userToVoteToAttendance[_msgSender()][voteId].amount == 0, 
                "QAO Voting Engine: Sender already attended this vote.");
        
        require(lockWeeks >= 0 && lockWeeks <= 520, 
                "QAO Voting Engine: Token locking time needs to be between 1 week and 10 years (520 weeks).");
        
        require(lockOption >= 0 && lockOption <= 2,
                "QAO Voting Engine: Lock option any only be 0, 1 or 2.");
        

        // *** step 2 - calculate reward/voting weight ***
        uint256 votingMultiplier = lockOption == 2 ? _weekToMultiplier[lockWeeks] : 1 ether;
        uint256 votingWeight = (tokenAmount * votingMultiplier) / DIV_ACCURACY;

        uint256 timestamp = 0;
        if (lockOption == 1){ //timestamp is the vote time for later reward calculation
            timestamp = block.timestamp;
        }
        if (lockOption == 2){ //timestamp is the unlock time 
            timestamp = block.timestamp + (lockWeeks * WEEK_IN_SECONDS);
        }
        
        _userToVoteToAttendance[_msgSender()][voteId] = VoteAttendance(votingWeight, timestamp, lockOption, position, false);

        // mint the reward for option 2 users and lock it with the staked amount of token
        uint256 reward = votingWeight - tokenAmount;
        _qaoToken.mintVoteStakeReward(reward);

        // *** step 3 - update vote ***
        if (position){
            _idToVote[voteId].votePositive = _idToVote[voteId].votePositive + votingWeight;
        }
        else {
            _idToVote[voteId].voteNegative = _idToVote[voteId].voteNegative + votingWeight;
        }

        // check if end of vote has been reached
        if ((_idToVote[voteId].votePositive + _idToVote[voteId].voteNegative) >= END_VOTE_AMOUNT){
            _idToVote[voteId].active = false;
            _idToVote[voteId].endTimestamp = block.timestamp;
            emit EndOfVote(voteId);
        }
    }


    function withdrawFromVote(uint256 voteId) external validVote(voteId) {
        
        require(!_userToVoteToAttendance[_msgSender()][voteId].withdrawn,
                "QAO Voting Engine: Token have already been withdrawn.");
        
        uint8 option =  _userToVoteToAttendance[_msgSender()][voteId].lockOption;

        // option 0 = no locking
        if (option == 0) {
            uint256 amount = _userToVoteToAttendance[_msgSender()][voteId].amount;
            _qaoToken.transfer(_msgSender(), amount);
            _userToVoteToAttendance[_msgSender()][voteId].withdrawn = true;

            // if vote is still active, the vote becomes invalid
            if(_idToVote[voteId].active){
                if(_userToVoteToAttendance[_msgSender()][voteId].position){
                    _idToVote[voteId].votePositive = _idToVote[voteId].votePositive - amount;
                }
                else {
                    _idToVote[voteId].voteNegative = _idToVote[voteId].voteNegative - amount;
                }
            }
        }

        // option 1 = until vote end (including special case for vore creator)
        else if (option == 1) {
            
            require(!_idToVote[voteId].active, "QAO Voting Engine: Tokens are still locked (option 1).");
            // calculate passed weeks & reward
            uint256 timeDiff = _idToVote[voteId].endTimestamp - _userToVoteToAttendance[_msgSender()][voteId].timestamp;
            uint256 passedWeeks = timeDiff / WEEK_IN_SECONDS;
            uint256 rewardMultiplier = _weekToMultiplier[passedWeeks];
            uint256 reward = (_userToVoteToAttendance[_msgSender()][voteId].amount * rewardMultiplier) / DIV_ACCURACY;
            reward = reward - _userToVoteToAttendance[_msgSender()][voteId].amount;

            // apply additional multiplier if sender is creator of the vote
            if (_idToVote[voteId].creator == _msgSender()){
                reward = reward * 2;
            }

            // mint reward and transfer whole token amount
            _qaoToken.mintVoteStakeReward(reward);
            _qaoToken.transfer(_msgSender(), _userToVoteToAttendance[_msgSender()][voteId].amount + reward);
            _userToVoteToAttendance[_msgSender()][voteId].withdrawn = true;
        }

        // option 2 = until end of lock time has been reached
        else {
            require(block.timestamp >= _userToVoteToAttendance[_msgSender()][voteId].timestamp,
                "QAO Voting Engine: Tokens used for this vote are still locked (option 2).");
            _qaoToken.transfer(_msgSender(), _userToVoteToAttendance[_msgSender()][voteId].amount);
            _userToVoteToAttendance[_msgSender()][voteId].withdrawn = true;
        }
    }

    /*******************************************************************
     * Getters/ Setters for week-based reward multiplier
     *******************************************************************/ 

    function rewardByWeek(uint256 week) external view returns (uint256) {
        require(week >= 0 && week <= 520, 
                "QAO Voting Engine: week needs to be between 1 week and 10 years (520 weeks).");
        return _weekToMultiplier[week];
    }

    function setRewardByWeek(uint256 week, uint256 reward) external onlyOwner {
        require(week >= 0 && week <= 520, 
                "QAO Voting Engine: week needs to be between 1 week and 10 years (520 weeks).");
        _weekToMultiplier[week] = reward;
    }

    /*******************************************************************
     * Vote Getters
     *******************************************************************/
    function voteHeading(uint256 voteId) public view validVote(voteId) returns (string memory) {
        return _idToVote[voteId].heading;  
    }

    function voteDescription(uint256 voteId) public view validVote(voteId) returns (string memory) {
        return _idToVote[voteId].description; 
    }

    function voteCreator(uint256 voteId) public view validVote(voteId) returns (address) {
        return _idToVote[voteId].creator; 
    }

    function voteCreationTimestamp(uint256 voteId) public view validVote(voteId) returns (uint256) {
        return _idToVote[voteId].creationTimestamp; 
    }

    function voteEndTimestamp(uint256 voteId) public view validVote(voteId) returns (uint256) {
        return _idToVote[voteId].endTimestamp; 
    }

    function voteIsActive(uint256 voteId) public view validVote(voteId) returns (bool) {
        return _idToVote[voteId].active; 
    }

    function voteSuccess(uint256 voteId) public view validVote(voteId) returns (bool) {
        return _idToVote[voteId].votePositive > _idToVote[voteId].voteNegative; 
    }

    function voteResultPositive(uint256 voteId) public view validVote(voteId) returns (uint256) {
        return _idToVote[voteId].votePositive; 
    }

    function voteResultNegative(uint256 voteId) public view validVote(voteId) returns (uint256) {
        return _idToVote[voteId].voteNegative; 
    }

}