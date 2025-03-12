// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../common/Ownable.sol";

interface Battle {
    function leave(address _user, uint256 _amount) external;
}

contract vEmpireGame is Ownable {
    using SafeMath for uint256;

    // Battle info each room Id
    struct BattleInfo {
        address player1;
        address player2;
        uint256 poolAmount;
        uint256 riskPercent;
        string roomId;
        address winnerAddress;
        bool claimStatus;
    }

    // User Info of each battle Id
    struct UserInfo {
        address player2;
        string roomId;
        bool xsVempLockStatus;
    }

    // Info of each Battle
    mapping(string => BattleInfo) public battleInfo;

    // Info of each user that participate in Battle.
    mapping(string => mapping(address => UserInfo)) public userInfo;

    // xsVemp token address
    address public xsVemp;

    // Battle contract address
    address public battleAddress;

    // DDAO contract address
    address public ddaoAddress;

    // ddao ddaoPercent
    uint256 public daoPercent;

    // total ddao tokens
    uint256 public daoTokens;

    // min xsVemp tokens to participate into the pool
    uint256 public minBattleTokens = 1000000000000000000;

    // Admin list
    mapping(address => bool) public adminStatus;

    // players list for lottery airdrop rewards
    address[] private playersForAirdrop;

    // winners list
    address[] public winners;

    // battleIds list
    string[] public battleIds;

    mapping(string => address) public loser;

    function initialize(address owner_, address _xsVemp, address _battleAddress, uint256 _ddaoPercent, address _ddaoAddress) public initializer {        
        require(_xsVemp != address(0), "Invalid _xsVemp address");
        require(_battleAddress != address(0), "Invalid _battleAddress address");
        require(owner_ != address(0), "Invalid owner_ address");
        require(_ddaoAddress != address(0), "Invalid _ddaoAddress address");

        Ownable.init(owner_);
        xsVemp = _xsVemp;
        daoPercent = _ddaoPercent;
        battleAddress = _battleAddress;
        ddaoAddress = _ddaoAddress;
    }

    modifier onlyAdmin() {
        require(adminStatus[_msgSender()], "Caller is not admin");
        _;
    }

    /**
     * @dev Return list of players addresses for airdrop 
     */
    function getPlayersForAirdrop()
        public
        view
        onlyAdmin
        returns (address[] memory)
    {
        return playersForAirdrop;
    }

    /**
     * @dev Used externally, used to participate in battle 
     *
     * @param _poolAmount pool Amount to lock xsVemp tokens to play game
     * @param _riskPercent represent risk Percent to play game
     * @param _roomId room Id represents index or room identity of both players 
     */
    function battleLockTokens(
        uint256 _poolAmount,
        uint256 _riskPercent,
        string memory _roomId
    ) external {
        if (_poolAmount == 0 || _riskPercent == 0 || keccak256(bytes(_roomId)) == keccak256(bytes(""))) {
            revert("Invalid data");
        }
        require(
            _poolAmount >= minBattleTokens,
            "Pool amount can not less than min battle tokens"
        );

        BattleInfo storage battle = battleInfo[_roomId];
        UserInfo storage user = userInfo[_roomId][msg.sender];

        require(battle.winnerAddress == address(0), "Battle already ended");
        if (battle.player1 != address(0)) {
            require(
                keccak256(bytes(battle.roomId)) == keccak256(bytes(_roomId)) && battle.player2 == address(0),
                "Invalid room id data"
            );
            require(
                battle.riskPercent == _riskPercent &&
                    battle.poolAmount == _poolAmount,
                "Invalid risk and pool"
            );
            require(battle.player1 != msg.sender, "Room id already used");
            UserInfo storage user2 = userInfo[_roomId][battle.player1];
            battle.player2 = msg.sender;
            user2.player2 = msg.sender;
            user.player2 = battle.player1;
            user.roomId = _roomId;
            user.xsVempLockStatus = false;
            playersForAirdrop.push(msg.sender);
        } else {
            require(
                battle.player1 == address(0) && battle.player2 == address(0),
                "Room id already used"
            );
            battle.player1 = msg.sender;
            battle.player2 = address(0);
            battle.poolAmount = _poolAmount;
            battle.riskPercent = _riskPercent;
            battle.roomId = _roomId;
            battle.winnerAddress = address(0);

            user.player2 = address(0);
            user.roomId = _roomId;
            user.xsVempLockStatus = false;
            playersForAirdrop.push(msg.sender);
            battleIds.push(_roomId);
        }

        if (!user.xsVempLockStatus) {
            IERC20(xsVemp).transferFrom(msg.sender, address(this), _poolAmount);
            user.xsVempLockStatus = true;
        }
    }

    /**
     * @dev Used externally only by admin, used to update winner address from back-end 
     *
     * @param _roomId room Id represents index or room identity of both players 
     * @param _winnerAddress address of winner player
     */
    function updateWinnerAddress(address[] memory _winnerAddress, string[] memory _roomId)
        public
        onlyAdmin
    {
        require(_winnerAddress.length == _roomId.length, "Invalid data for winners");
        for(uint256 i=0; i<_winnerAddress.length; i++) {
            BattleInfo storage battle = battleInfo[_roomId[i]];
            UserInfo storage user1 = userInfo[_roomId[i]][battle.player1];
            UserInfo storage user2 = userInfo[_roomId[i]][battle.player2];

            require(_winnerAddress[i] != address(0) && (battle.player1 == _winnerAddress[i] || battle.player2 == _winnerAddress[i]), "Invalid Winner Address");
            require(battle.player1 != address(0) || battle.player2 != address(0), "Invalid players");
            require(
                user1.xsVempLockStatus != false || user2.xsVempLockStatus != false,
                "Invalid users lock status"
            );
            require(battle.winnerAddress == address(0), "Winner already declared");

            battle.winnerAddress = _winnerAddress[i];

            address _loser = _winnerAddress[i] == battle.player1
                ? battle.player2
                : battle.player1;
            if(_loser != address(0)) {
                playersForAirdrop.push(_loser);
            }
            loser[_roomId[i]] = _loser;
            winners.push(battle.winnerAddress);
        }
    }

    /**
     * @dev Used externally, used to claim battle rewards 
     *
     * @param _roomId room Id represents index or room identity of both players
     */
    function claimBattleRewards(string memory _roomId) public {
        BattleInfo storage battle = battleInfo[_roomId];
        UserInfo storage user = userInfo[_roomId][msg.sender];

        require(
            battle.player1 != address(0) || battle.player2 != address(0),
            "Invalid players address"
        );
        require(battle.winnerAddress != address(0), "Battle result in pending");
        require(
            battle.winnerAddress == _msgSender(),
            "Only winner can call this method"
        );
        require(user.xsVempLockStatus != false, "Invalid users lock status");
        require(battle.claimStatus != true, "Already claimed");

        if(battle.player2 != address(0)) {
            uint256 winnerShare = 100;
            uint256 winnerAmount = battle.poolAmount.mul(2).mul(winnerShare.sub(daoPercent)).div(100);
            daoTokens = daoTokens.add((battle.poolAmount.mul(2).sub(winnerAmount)));
            IERC20(xsVemp).transfer(
                battle.winnerAddress,
                winnerAmount
            );
        } else {
            IERC20(xsVemp).transfer(
                battle.winnerAddress,
                battle.poolAmount
            );
        }
        battle.claimStatus = true;
    }

    /**
     * @dev Used only by admin or owner, used to withdraw ddao xsVemp tokens
     *
     * @param _amount amount of xsVemp and must be less than total ddao amount
     */
    function withdrawxsVempFeeTokensToVemp(uint256 _amount)
        public
        onlyOwner
    {
        require(daoTokens >= _amount, "Insufficiently amount");
        IERC20(xsVemp).approve(address(battleAddress), _amount);
        Battle(battleAddress).leave(ddaoAddress, _amount);
        daoTokens = daoTokens.sub(_amount);
    }

    /**
     * @dev Used only by admin or owner, used to withdraw ddao xsVemp tokens
     *
     * @param _to address of xsVemp tokens receiver
     * @param _amount amount of xsVemp and must be less than total ddao amount
     */
    function withdrawxsVempFeeTokens(address _to, uint256 _amount)
        public
        onlyOwner
    {
        require(_to != address(0), "Invalid to address");
        require(daoTokens >= _amount, "Insufficiently amount");
        IERC20(xsVemp).transfer(_to, _amount);
        daoTokens = daoTokens.sub(_amount);
    }

    /**
     * @dev Used only by admin or owner, used to update admin
     *
     * @param _admin address of new admin 
     * @param _status status of admin true if provide access otherwise false to remove access 
     */
    function updateAdmin(address _admin, bool _status) public onlyOwner {
        require(adminStatus[_admin] != _status, "Already in same status");
        adminStatus[_admin] = _status;
    }

    /**
     * @dev Used only by admin or owner, used to update min battle token amount, by default its 0
     *
     * @param _minBattleTokens amount of xsVemp tokens must hold or locked by user to participate in battle
     */
    function updateMinBattleTokens(uint256 _minBattleTokens) public onlyOwner {
        minBattleTokens = _minBattleTokens;
    }

    /**
     * @dev Used only by admin or owner, used to update dao percent, by default its 0
     *
     * @param _ddaoPercent dao percent to send on ddao contract for distribution to all vemp stakers
     */
    function updateDDAOPercent(uint256 _ddaoPercent) public onlyOwner {
        require(_ddaoPercent <= 100, "Invalid Dao Percent");
        daoPercent = _ddaoPercent;
    }

    /**
     * @dev Used only by admin or owner, used to dao contract, by default its 0 address
     *
     * @param _battleAddress dao contract address to 
     */
    function updateBattleAddress(address _battleAddress) public onlyOwner {
        require(_battleAddress != address(0), "Invalid _battleAddress address");
        battleAddress = _battleAddress;
    }

    /**
     * @dev Used only by admin or owner, used to dao contract, by default its 0 address
     *
     * @param _ddaoAddress dao contract address to 
     */
    function updateDDAOAddress(address _ddaoAddress) public onlyOwner {
        require(_ddaoAddress != address(0), "Invalid _ddaoAddress address");
        ddaoAddress = _ddaoAddress;
    }

    /**
     * @dev Used only by admin or owner, used to withdraw locked xsVemp tokens in emergency
     *
     * @param _to address of xsVemp tokens receiver
     * @param _amount amount of xsVemp and must be less than total locked amount
     */
    function emergencyWithdrawxsVempTokens(address _to, uint256 _amount)
        public
        onlyOwner
    {
        require(_to != address(0), "Invalid _to address");
        uint256 vempBal = IERC20(xsVemp).balanceOf(address(this));
        require(vempBal >= _amount, "Insufficiently amount");
        IERC20(xsVemp).transfer(_to, _amount);
    }

    /**
     * @dev Used only by owner, used to update winner in emergency
     *
     * @param _roomId room Id represents index or room identity of both players 
     * @param _winnerAddress address of winner player
     */
    function updateWinnerInEmergency(string memory _roomId, address _winnerAddress)
        public
        onlyOwner
    {
        BattleInfo storage battle = battleInfo[_roomId];
        UserInfo storage user1 = userInfo[_roomId][battle.player1];
        UserInfo storage user2 = userInfo[_roomId][battle.player2];

        require(_winnerAddress != address(0) && (battle.player1 == _winnerAddress || battle.player2 == _winnerAddress), "Invalid Winner Address");
        require(
            battle.player1 != address(0) || battle.player2 != address(0),
            "Invalid players"
        );
        require(
            user1.xsVempLockStatus != false || user2.xsVempLockStatus != false,
            "Invalid users lock status"
        );
        require(battle.claimStatus != true, "Already claimed");

        battle.winnerAddress = _winnerAddress;

        address _loser = _winnerAddress == battle.player1
            ? battle.player2
            : battle.player1;
        if(_loser != address(0)) {
            playersForAirdrop.push(_loser);
        }
        loser[_roomId] = _loser;
        winners.push(battle.winnerAddress);
    }
}
