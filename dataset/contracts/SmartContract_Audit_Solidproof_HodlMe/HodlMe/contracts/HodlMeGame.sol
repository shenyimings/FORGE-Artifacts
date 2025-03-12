//SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "./standard/Ownable.sol";
import "./interface/IERC20.sol";
import "hardhat/console.sol";

contract HodlMeGame is Ownable {
    uint256 constant GAME_CREATED = 1;
    uint256 constant GAME_STARTED = 2;
    uint256 constant GAME_ENDED = 3;
    uint256 constant GAME_MINIMUM_PLAY_TIME_IN_SECONDS = 300;

    uint256 private gameIdCount = 1;

    struct Game {
        address player1;
        address player2;
        uint256 gameState;
        uint256 amount;
        uint256 creationTime;
        uint256 lastModifiedTime;
        address winner;
    }

    mapping(uint256 => Game) public games;

    mapping(address => uint256) public userGamesCount;
    mapping(address => uint256) public userEndedGamesCount;
    mapping(address => mapping(uint256 => uint256)) public userActiveGames;
    mapping(address => mapping(uint256 => uint256)) public userEndedGames;

    address gameToken;
    IERC20 gameTokenContract;

    event GameCreated(
        address indexed player,
        uint256 indexed amount,
        uint256 gameId
    );
    event GameStarted(
        address indexed player1,
        address indexed player2,
        uint256 indexed amount,
        uint256 gameId
    );
    event GameEnded(
        address indexed player1,
        address indexed player2,
        uint256 indexed amount,
        uint256 gameId
    );
    event GameContinuesAfterDraw(
        address indexed player1,
        address indexed player2,
        uint256 indexed amount,
        uint256 gameId
    );
    event LeftGame(
        address indexed player,
        uint256 indexed amount,
        uint256 gameId
    );

    constructor(address _gameToken) {
        gameToken = _gameToken;
        gameTokenContract = IERC20(gameToken);
    }

    function newGame(uint256 amount) public {
        uint256 gameId = gameIdCount++;
        Game storage game = games[gameId];
        game.player1 = _msgSender();
        game.amount = amount;
        game.gameState = GAME_CREATED;
        game.creationTime = block.timestamp;
        game.lastModifiedTime = block.timestamp;
        userActiveGames[_msgSender()][userGamesCount[_msgSender()]] = gameId;
        userGamesCount[_msgSender()]++;
        gameTokenContract.transferFrom(_msgSender(), address(this), amount);
        emit GameCreated(game.player1, amount, gameId);
    }

    function joinGame(uint256 gameId) public {
        Game storage game = games[gameId];
        require(
            game.gameState == GAME_CREATED,
            "This game is not available or doesn't exist"
        );
        require(
            _msgSender() != game.player1,
            "You can't join your own private game."
        );
        game.player2 = _msgSender();
        userActiveGames[_msgSender()][userGamesCount[_msgSender()]] = gameId;
        userGamesCount[_msgSender()]++;
        game.gameState = GAME_STARTED;
        game.lastModifiedTime = block.timestamp;

        gameTokenContract.transferFrom(
            _msgSender(),
            address(this),
            game.amount
        );
        emit GameStarted(game.player1, game.player2, game.amount, gameId);
    }

    function leaveGame(uint256 gameId) public {
        Game storage game = games[gameId];
        require(
            game.player1 == _msgSender(),
            "You are not playing in this game."
        );
        require(
            game.gameState == GAME_CREATED,
            "Only games with not all players can be left."
        );
        require(
            block.timestamp - game.creationTime >=
                GAME_MINIMUM_PLAY_TIME_IN_SECONDS,
            "Cannot leave game before the minimum waiting time"
        );

        game.gameState = GAME_ENDED;
        game.lastModifiedTime = block.timestamp;
        gameTokenContract.transfer(_msgSender(), game.amount);

        emit LeftGame(game.player1, game.amount, gameId);
    }

    modifier onlyGameToken() {
        require(
            gameToken == _msgSender(),
            "You're not allowed to use this function"
        );
        _;
    }

    function endUserGames(address loser) external onlyGameToken {
        uint256 j = 0;
        for (uint256 i = 0; i < userGamesCount[loser]; i++) {
            uint256 gameId = userActiveGames[loser][i];
            Game storage game = games[gameId];
            if (game.gameState == GAME_STARTED) {
                game.gameState = GAME_ENDED;
                game.lastModifiedTime = block.timestamp;
                if (loser == game.player1) {
                    game.winner = game.player2;
                } else {
                    game.winner = game.player1;
                }
                gameTokenContract.transfer(game.winner, game.amount * 2);
                userEndedGames[loser][userEndedGamesCount[loser]] = userActiveGames[loser][i];
                userEndedGamesCount[loser]++;

                userEndedGames[game.winner][userEndedGamesCount[game.winner]] = userActiveGames[loser][i];
                userEndedGamesCount[game.winner]++;
            } else if (game.gameState == GAME_CREATED) {
                userActiveGames[loser][j] = userActiveGames[loser][i];
                j++;
            } else {
                userEndedGames[loser][userEndedGamesCount[loser]] = userActiveGames[loser][i];
                userEndedGamesCount[loser]++;
            }
        }
        userGamesCount[loser] = j;
    }

    function gamesCount() public view returns (uint256) {
        return gameIdCount - 1;
    }
}
