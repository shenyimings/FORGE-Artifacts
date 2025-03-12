// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../utils/Ownable.sol";
import "../token/ILitlabGamesToken.sol";
import "../metatx/LitlabContext.sol";

/// SmartContract for CyberTitans game modality. It's a centralized SmartContract.
/// Working mode:
/// - This SmartContract is intended to manage the user tournament join, retirement and distribute prizes
/// - Previously, users have approved this contract to spend LitlabGames ERC20 token in the litlabgames webpage
/// - Then, when users want to connect to the tournament, when matchmaking is done (8 players), in the server, we call the functions:
///     - createTournament: To create a new tournament. Returns a tournament id
///     - joinTournament: To join a new user to a tournament
///     - retireTournament: To retire a user from a tournament (deactivated for now. nobody could retire once joined)
///     - finalizeTournament: When tournament has finished, send the winner wallets and distribute the prizes according the prizes matrix
contract CyberTitansTournament is LitlabContext, Ownable {
    using SafeERC20 for IERC20;

    struct TournamentStruct {
        uint256 playerBet;                  // Tournament bet for each player
        uint256 tournamentAssuredAmount;    // Tournament minimum prize
        address token;                      // Tournament token
        uint24 numOfTokenPlayers;           // Num of players betting with LITTs
        uint24 numOfCTTPlayers;             // Num of players playing with CTT (softcoin of the game not used in blockchain)
        uint64 startDate;                   // Tournament start date
        uint64 endDate;                     // Tournament end date
    }
    mapping(uint256 => TournamentStruct) private tournaments;   // Mapping with Tournaments
    uint256 public tournamentCounter;                           // To calculate next tournamentId

    address public wallet;                                      // Wallet with LITTs to take when player bets don't make the minimum tournament amount
    address public manager;                                     // Account authorized to call the contract from a backend
    address public litlabToken;                                 // LitlabGames token

    uint32[][8] public prizes;                                  // Matrix of prizes
    uint32[][8] public players;                                 // Matrix of players
    uint32[][12] public tops;                                   // Matrix of tops
    uint8[8] public winners = [3, 4, 6, 8, 16, 32, 64, 128];    // Array of winners according to tournament players number

    uint16 public rake = 25;
    uint16 public fee = 25;
    bool private pause;

    event ManagerChanged(address indexed _manager);
    event WalletChanged(address indexed _wallet);
    event LitlabTokenChanged(address indexed _litlabToken);
    event FeesUpdated(uint16 _fee, uint16 _rake);
    event PauseChanged(bool _paused);
    event TournamentCreated(uint256 _tournamentId);
    event TournamentFinalized(uint256 _tournamentId);
    event TournamentJoined(uint256 _id, address indexed _player);
    event TournamentStarted(uint256 _id, uint24 _litPlayers, uint24 _cttPlayers);
    event EmergencyWithdrawn(uint256 _balance, address indexed _token);

    /// Modifiers
    modifier onlyManager() {
        require(manager == _msgSender(), "OnlyManager");
        _;
    }

    modifier notPaused() {
        require(!pause, "Paused");
        _;
    }

    // Initialize the data and build the matrix according to the tokenomics
    constructor(
        address _forwarder, 
        address _manager, 
        address _wallet, 
        address _litlabToken
    ) LitlabContext(_forwarder) {
        require(_forwarder != address(0), "ZeroAddress");
        require(_manager != address(0), "ZeroAddress");
        require(_wallet != address(0), "ZeroAddress");
        require(_litlabToken != address(0), "ZeroAddress");

        manager = _manager;
        wallet = _wallet;
        litlabToken = _litlabToken;

        _buildArrays();

        emit ManagerChanged(_manager);
        emit WalletChanged(_wallet);
        emit LitlabTokenChanged(_wallet);
    }

    function changeManager(address _manager) external onlyOwner {
        require(_manager != address(0), "ZeroAddress");
        manager = _manager;
        emit ManagerChanged(_manager);
    }

    function changeWallet(address _wallet) external onlyOwner {
        require(_wallet != address(0), "ZeroAddress");
        wallet = _wallet;
        emit WalletChanged(_wallet);
    }

    function changeLitlabToken(address _litlabToken) external onlyOwner {
        require(_litlabToken != address(0), "ZeroAddress");
        litlabToken = _litlabToken;
        emit LitlabTokenChanged(_litlabToken);
    }

    function updateFees(uint16 _fee, uint16 _rake) external onlyOwner {
        require(_fee + _rake <= 50, "BadFees");
        
        fee = _fee;
        rake = _rake;

        emit FeesUpdated(_fee, _rake);
    }

    function changePause() external onlyOwner {
        pause = !pause;
        emit PauseChanged(pause);
    }

    // To create the tournament only need. Token address, start date, bet for each player and minimum tournament prize
    // Returns the tournamentId
    function createTournament(
        address _token, 
        uint64 _startDate, 
        uint256 _playerBet, 
        uint256 _tournamentAssuredAmount
    ) external onlyManager notPaused {
        require(_playerBet != 0, "BadAmount");
        require(_tournamentAssuredAmount != 0, "BadAmount");
        require(_token != address(0), "BadToken");

        uint256 tournamentId = ++tournamentCounter;
        TournamentStruct storage tournament = tournaments[tournamentId];
        tournament.token = _token;
        tournament.playerBet = _playerBet;
        tournament.tournamentAssuredAmount = _tournamentAssuredAmount;
        if (_startDate > 0) tournament.startDate = _startDate;

        emit TournamentCreated(tournamentId);
    }

    // A player joins the tournament only using the id
    function joinTournament(uint256 _id) external notPaused {
        TournamentStruct storage tournament = tournaments[_id];
        if (tournament.startDate > 0) require(block.timestamp >= tournament.startDate, "NotStarted");
        require(tournament.token != address(0), "NoTournament");
        require(tournament.endDate == 0, "TournamentEnded");

        tournament.numOfTokenPlayers++;
        IERC20(tournament.token).safeTransferFrom(_msgSender(), address(this), tournament.playerBet);

        emit TournamentJoined(_id, _msgSender());
    }

    // Get tournament data
    function getTournament(uint256 _id) external view returns(TournamentStruct memory) {
        return tournaments[_id];
    }

    // Server indicates that the tournament is going to start (this is not the exact moment when starting)
    // Reports the number of players with LITTs and CTT tickets.
    // We need this data to calculate the prizes properly in the finalizeTournament function
    function startTournament(uint256 _id, uint24 _litPlayers, uint24 _cttPlayers) external onlyManager notPaused {
        TournamentStruct storage tournament = tournaments[_id];
        require(_litPlayers == tournament.numOfTokenPlayers, "BadLITTPlayers"); // Check the server reports the same LITT users that we count in the smartcontract
        require(tournament.token != address(0), "NoTournament");
        require(tournament.endDate == 0, "TournamentEnded");
        tournament.numOfCTTPlayers = _cttPlayers;   // Report the CTT tickets free2play players

        emit TournamentStarted(_id, _litPlayers, _cttPlayers);
    }

    // Server calls this function and the smartcontract give the prizes according the matrix data
    // Server only reports an array with winners. We calculate the prizes
    function finalizeTournament(
        uint256 _tournamentId,
        address[] calldata _winners
    ) external onlyManager notPaused {
        TournamentStruct storage tournament = tournaments[_tournamentId];
        address token = tournament.token;
        uint256 assuredAmount = tournament.tournamentAssuredAmount;
        require(tournament.endDate == 0, "TournamentEnded");
        require(token != address(0), "NoTournament");
        
        tournament.endDate = uint64(block.timestamp);

        // Get the num of players in the tournament
        uint24 numOfPlayers = tournament.numOfTokenPlayers + tournament.numOfCTTPlayers;
        // Get the prizes array
        uint256 index = _getPrizesColumn(numOfPlayers);
        require(winners[index] == _winners.length, "BadWinners");

        // Calculate if we got the minimum assurance token amount for the tournament. Otherwise, the game will add the tokens
        uint256 amountPlayed = tournament.playerBet * tournament.numOfTokenPlayers;
        if (amountPlayed < assuredAmount) {
            IERC20(token).safeTransferFrom(wallet, address(this), assuredAmount - amountPlayed);
            amountPlayed = assuredAmount;
        }

        // Burn those tokens
        uint256 _rake = amountPlayed * rake / 1000;
        // Fee
        uint256 _fee = amountPlayed * fee / 1000;
        // Tournament pot
        uint256 pot = amountPlayed - (_rake + _fee);

        // For each player in the winners array
        uint8 i;
        do {
            // Get the player's prize
            uint256 prizePercentage = _getPrize(index, i+1);
            uint256 prize = (pot * prizePercentage) / (10 ** 7);
            if (prize != 0) IERC20(token).safeTransfer(_winners[i], prize);
            unchecked {
                ++i;
            }
        } while(i<_winners.length);

        // Burn the rake and get the fee
        if (token == litlabToken) {
            // If we are using litlabtoken, burn the rake
            ILitlabGamesToken(token).burn(_rake);
            IERC20(token).safeTransfer(wallet, _fee);
        } else {
            // If we are using other token, transfer the rake instead of burning
            IERC20(token).safeTransfer(wallet, (_rake + _fee));
        }

        emit TournamentFinalized(_tournamentId);
    }

    // If something happens, owner can withdraw the LITT funds of this contract
    function emergencyWithdraw(address _token) external onlyOwner {
        require(_token != address(0), "ZeroAddress");
        uint256 balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(owner, balance);

        emit EmergencyWithdrawn(balance, _token);
    }

    function _getPrizesColumn(uint24 _numOfPlayers) internal view returns(uint16) {
        uint16 index;
        do {
            if (_numOfPlayers >= players[index][0] && _numOfPlayers <= players[index][1]) break;
            unchecked {
                ++index;
            }
        } while (index < 8);
    
        assert(index < 8);
        return index;
    }

    function _getPrize(uint256 _index, uint256 _position) internal view returns(uint32) {
        uint8 index;
        do {
            if (_position >= tops[index][0] && _position <= tops[index][1]) break;
            unchecked {
                ++index;
            }
        } while(index < 12);

        assert(index < 12);
        return prizes[_index][index];
    }

    
    function _buildArrays() internal {
        prizes[0] = [5000000, 3000000, 2000000];
        prizes[1] = [4000000, 2700000, 1900000, 1400000];
        prizes[2] = [3200000, 2200000, 1650000, 1250000, 900000, 800000];
        prizes[3] = [2975000, 1875000, 1475000, 1125000, 850000, 700000, 550000, 450000];
        prizes[4] = [2575000, 1705000, 1100000, 850000, 625000, 500000, 400000, 317000, 241000];
        prizes[5] = [2000000, 1400000, 945000, 770000, 600000, 500000, 400000, 312500, 164062, 110000];
        prizes[6] = [1825000, 1325000, 842000, 700000, 562500, 460000, 360000, 265000, 130000, 73001, 45390];
        prizes[7] = [1780000, 1275000, 785000, 609200, 507500, 412000, 320000, 232500, 105000, 51000, 31712, 22000];

        players[0] = [1,8];
        players[1] = [9,16];
        players[2] = [17,32];
        players[3] = [33,64];
        players[4] = [65,128];
        players[5] = [129,256];
        players[6] = [257,512];
        players[7] = [512,1024];

        tops[0] = [1,1];
        tops[1] = [2,2];
        tops[2] = [3,3];
        tops[3] = [4,4];
        tops[4] = [5,5];
        tops[5] = [6,6];
        tops[6] = [7,7];
        tops[7] = [8,8];
        tops[8] = [9,16];
        tops[9] = [17,32];
        tops[10] = [33,64];
        tops[11] = [65,128];
    }
}