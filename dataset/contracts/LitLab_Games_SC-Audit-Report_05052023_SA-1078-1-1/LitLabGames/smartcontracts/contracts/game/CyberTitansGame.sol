// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../utils/Ownable.sol";
import "../token/ILitlabGamesToken.sol";
import "../metatx/LitlabContext.sol";

/// SmartContract for CyberTitans game modality. It's a centralized SmartContract.
/// Working mode:
/// - This SmartContract is intended to manage the user bets in the cybertitans game
/// - Previously, users have approved this contract to spend LitlabGames ERC20 token in the litlabgames webpage
/// - Then, when users want to connect to the game, when matchmaking is done (8 players), in the server, we call the functions:
///     - checkWallets: To check that the smartcontract can get tokens from every player involved in the matchmaking
///     - createGame: Get tokens for each player in the matchmaking
///     - finalizeGame: When game has finished, there're only 3 winners. Split the tokens between the winners, get the platform fee and burn tokens
contract CyberTitansGame is LitlabContext, Ownable {
    using SafeERC20 for IERC20;

    // To store game data
    struct GameStruct {
        address[] players;
        uint256 totalBet;
        address token;
        uint64 startDate;
        uint64 endDate;
    }
    mapping(uint256 => GameStruct) private games;   // Mapping to get GameStruct by an ID
    uint256 public gameCounter;                     // To get a game ID each time createGame is called

    uint256 public maxBetAmount;                    // Security. Don't let create a game with a bet greater than this variable

    address public wallet;                          // Company wallet. To send the game fees
    address public manager;                         // Account with elevated permissions to call functions
    address public litlabToken;                     // LitlabGames token address

    uint16[] public winnersPercentages = [475, 285, 190];      // Each game has 3 winners. They get 47.5%, 28.5% and 19% of the total pool each
    uint16 public rake = 25;                        // Burn 2.5% each game
    uint16 public fee = 25;                         // Fee 2.5%
    uint16 public waitMinutes = 15;                 // Minimum delay between create and finalize game
    bool private pause;                             // To pause the smartcontract

    event ManagerChanged(address _manager);
    event WalletChanged(address _wallet);
    event LitlabTokenChanged(address _litlabToken);
    event WinnersChanged(uint16[] _winners, uint16 _fee, uint16 _rake);
    event WaitMinutesUpdated(uint16 _waitMinutes);
    event MaxBetAmountUpdated(uint256 _maxBetAmount);
    event PauseChanged(bool _pause);
    event GameCreated(uint256 _gameId);
    event GameFinalized(uint256 _gameId, address[] _winners);
    event EmergencyWithdrawn(uint256 _balance, address _token);

    /// Modifiers
    modifier onlyManager() {
        require(manager == _msgSender(), "OnlyManager");
        _;
    }

    modifier notPaused() {
        require(!pause, "Paused");
        _;
    }

    /// Constructor
    constructor(
        address _forwarder, 
        address _manager, 
        address _wallet, 
        address _litlabToken, 
        uint256 _maxBetAmount
    ) LitlabContext(_forwarder) {
        require(_forwarder != address(0), "ZeroAddress");
        require(_manager != address(0), "ZeroAddress");
        require(_wallet != address(0), "ZeroAddress");
        require(_litlabToken != address(0), "ZeroAddress");
        require(_maxBetAmount != 0, "BadMaxBet");

        manager = _manager;
        wallet = _wallet;
        litlabToken = _litlabToken;
        maxBetAmount = _maxBetAmount;

        emit ManagerChanged(_manager);
        emit WalletChanged(_wallet);
        emit LitlabTokenChanged(_litlabToken);
        emit MaxBetAmountUpdated(_maxBetAmount);
    }

    // Functions to change smartcontract variables
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

    function changeWinnersPercentages(uint16[] memory _winners, uint16 _fee, uint16 _rake) external onlyOwner {
        require(_winners.length > 0, "BadLength");

        uint256 checkSum;
        winnersPercentages = new uint16[](_winners.length);
        for (uint256 i=0; i< _winners.length; i++) {
            winnersPercentages[i] = _winners[i];
            checkSum += _winners[i];
        }

        fee = _fee;
        rake = _rake;

        checkSum = checkSum + fee + rake;
        require(checkSum == 1000, "BadCheckSum");

        emit WinnersChanged(_winners, _fee, _rake);
    }

    function updateWaitMinutes(uint16 _waitMinutes) external onlyOwner {
        waitMinutes = _waitMinutes;
        emit WaitMinutesUpdated(_waitMinutes);
    }

    function updateMaxBetAmount(uint256 _maxBetAmount) external onlyOwner {
        require(_maxBetAmount != 0, "BadMaxBet");
        maxBetAmount = _maxBetAmount;
        emit MaxBetAmountUpdated(_maxBetAmount);
    }

    function changePause() external onlyOwner {
        pause = !pause;
        emit PauseChanged(pause);
    }
    // End update functions

    /// Check if the wallet has enough tokens to join a game and if they approved the contract to spend their tokens in the litlabgames web page
    /// Returns 0 (Ok), 1 (Not approved), 2 (Not enough balance)
    function checkWallets(
        address[] memory _players, 
        uint256 _amount, 
        address _token
    ) external view returns (uint256[] memory) {
        uint256[] memory info = new uint256[](_players.length); 
        for (uint256 i=0; i<_players.length; i++) {
            uint256 balance = IERC20(_token).balanceOf(_players[i]);
            uint256 allowance = IERC20(_token).allowance(_players[i], address(this));

            if (allowance >= _amount && balance >= _amount) info[i] = 0;
            else if (balance < _amount) info[i] = 2;
            else if (allowance < _amount) info[i] = 1;
        }

        return info;
    }

    /// Creates a new game and get the bet tokens from all the players
    function createGame(address[] memory _players, address _token, uint256 _amount) external onlyManager notPaused {
        require(_players.length != 0, "BadArray");
        require(_amount != 0, "BadAmount");
        require(_amount <= maxBetAmount, "MaxAmount");
        require(_token != address(0), "BadToken");

        uint256 gameId = ++gameCounter;

        games[gameId] = GameStruct({
            players: _players,
            totalBet: _amount * _players.length,
            token: _token,
            startDate: uint64(block.timestamp),
            endDate: 0
        });

        uint256 playersLen = _players.length;
        for (uint256 i=0; i<playersLen; ) {
            IERC20(_token).safeTransferFrom(_players[i], address(this), _amount);
            unchecked {
                ++i;
            }
        }

        emit GameCreated(gameId);
    }

    /// Finalize a game. Send the tokens to the winners, take a fee and burn tokens
    function finalizeGame(uint256 _gameId, address[] calldata _winners) external onlyManager notPaused {
        require(_checkPlayers(_gameId, _winners), "BadPlayers");

        GameStruct storage game = games[_gameId];
        require(block.timestamp >= game.startDate + (waitMinutes * 1 minutes), "WaitXMinutes"); // Protection to avoid a hacker that got the private key from the server to withdraw
        require(game.endDate == 0, "AlreadyEnd");
        game.endDate = uint64(block.timestamp);
        
        uint256 totalBet = game.totalBet;
        address token = game.token;

        // Check that there's enought balance to transfer tokens to winners
        require(IERC20(token).balanceOf(address(this)) >= totalBet, "NotEnoughBalance");

        uint256 winnersLen = _winners.length;
        for (uint256 i=0; i<winnersLen; ) {
            IERC20(token).safeTransfer(_winners[i], totalBet * winnersPercentages[i] / 1000);
            unchecked {
                ++i;
            }
        }

        if (token == litlabToken) { 
            ILitlabGamesToken(token).burn(totalBet * rake / 1000); // Only burn if we are using litlab token
            IERC20(token).safeTransfer(wallet, totalBet * fee / 1000);
        } else {    // Otherwise, take the rake as fee too
            IERC20(token).safeTransfer(wallet, ((totalBet * rake) + (totalBet * fee)) / 1000);
        }

        emit GameFinalized(_gameId, _winners);
    }

    /// OnlyOwner function to withdraw the tokens if there's any problem in the smartcontract
    function emergencyWithdraw(address _token) external onlyOwner {
        require(_token != address(0), "ZeroAddress");
        uint256 balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(owner, balance);

        emit EmergencyWithdrawn(balance, _token);
    }

    /// Checks that all the winners in the finalizeGame function are original players in the game (were in the createGame function)
    function _checkPlayers(uint256 _gameId, address[] calldata _players) internal view returns(bool) {
        address[] memory gamePlayers = games[_gameId].players;

        uint256 playersLen = _players.length;
        uint256 playersOk;
        for (uint256 i=0; i<playersLen; ) {
            uint256 gamePlayersLen = gamePlayers.length;
            for (uint256 j=0; j<gamePlayersLen;) {
                if (_players[i] == gamePlayers[j]) {
                    ++playersOk;
                    break;
                }

                unchecked {
                    ++j;
                }
            }
            if (playersOk == _players.length) return true;

            unchecked {
                ++i;
            }
        }

        return false;
    }
}