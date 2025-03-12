// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./utils/VRFConsumerBaseUpgradeable.sol";
import "./utils/IVault.sol";
import "./utils/IGame.sol";

contract CoinFlip is
    Initializable,
    AccessControlUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    VRFConsumerBaseUpgradeable
{
    enum GameState {
        Ended,
        Waiting,
        OnGoing
    }

    enum CoinFace {
        Head,
        Tail
    }

    struct RoomInfo {
        GameState state;
        uint128 betAmount;
        uint256 gameId;
        uint256 expiredTime;
        address playerHead;
        address playerTail;
        address winner;
    }

    mapping(uint8 => RoomInfo) public rooms;
    mapping(bytes32 => uint8) public requests; // requestId => rId
    mapping(uint256 => uint256) public results; // rId => randomResult

    uint8 public maxRoom;
    uint8 public feeRate;
    uint128 public constant minBet = 100 wei;
    uint128 public maxBet;
    uint256 internal fee;
    uint256 public gId; //unique roomId

    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");
    bytes32 internal keyHash;

    IVault public vault;

    modifier onlyWaitingRoom(uint8 _rId) {
        require(
            rooms[_rId].state == GameState.Waiting,
            "CoinFlip.sol: Room is ongoing."
        );
        _;
    }

    event CreateNewRoom(
        uint8 indexed rId,
        address player,
        uint128 betAmount,
        CoinFace coinFace,
        GameState state,
        uint256 expiredTime,
        uint256 indexed gameId
    );

    event ExpiredRoom(
        uint8 indexed rId,
        address playerRefund,
        uint128 betAmount,
        uint256 indexed gameId
    );

    event JoinRoom(
        uint8 indexed rId,
        address player,
        GameState state,
        uint256 indexed gameId,
        uint256 gameStartTime
    );

    event ResolveRoom(
        uint8 indexed rId,
        address winner,
        uint128 winnerBet,
        uint128 fee,
        GameState state,
        uint256 indexed gameId,
        bytes32 requestId,
        uint256 randomness
    );

    event RequestedRandomness(
        bytes32 indexed requestId,
        uint8 indexed rId,
        uint256 indexed gameId
    );

    event FeeRate(uint8 feeRate);

    /**
     * Constructor inherits VRFConsumerBase
     *
     * Network: Kovan
     * Chainlink VRF Coordinator address: 0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9
     * LINK token address:                0xa36085F69e2889c224210F603D836748e7dC0088
     * Key Hash: 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4
     * fee = 0.1 * 10**18; // 0.1 LINK
     *
     * Network: Polygon (Matic) Mumbai Testnet
     * Chainlink VRF Coordinator address: 0x8C7382F9D8f56b33781fE506E897a4F1e2d17255
     * LINK token address:                0x326C977E6efc84E512bB9C30f76E30c160eD06FB
     * Key Hash: 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4
     * fee = 1 * 10 ** 15 ; // 0.0001 LINK
     *
     */
    function initialize(
        address _vaultAddress,
        uint8 _maxRoom,
        uint128 _maxBet,
        bytes32 _keyhash,
        address _vrfCoordinator,
        address _linkToken,
        uint256 _fee
    ) public initializer {
        VRFConsumerBaseUpgradeable.__VRFConsumerBase_init(
            _vrfCoordinator, // VRF Coordinator
            _linkToken // LINK Token
        );

        // @dev deployer address will have default admin role which able to manage other role
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // OwnableUpgradeable
        OwnableUpgradeable.__Ownable_init();

        // AccessControlUpgradeable
        AccessControlUpgradeable.__AccessControl_init();
        _setupRole(VAULT_ROLE, _vaultAddress);

        // ReentrancyGuardUpgradeable
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        // PausableUpgradeable
        PausableUpgradeable.__Pausable_init();

        // @dev setting a playing vault (Punt token)
        vault = IVault(_vaultAddress);

        maxRoom = _maxRoom;
        maxBet = _maxBet;

        keyHash = _keyhash;
        fee = _fee;

        // default fee rate
        feeRate = 2;

        // for the graph
        emit CreateNewRoom(
            0,
            msg.sender,
            0,
            CoinFace.Head,
            GameState.Ended,
            0,
            0
        );
    }

    // setup max room
    function setMaxRoom(uint8 _maxRoom) external whenPaused onlyOwner {
        require(_maxRoom != 0, "CoinFlip.sol: Max Rooms can't be 0.");
        maxRoom = _maxRoom;
    }

    // setup max bet
    function setMaxBet(uint128 _maxBet) external whenPaused onlyOwner {
        require(_maxBet != 0, "CoinFlip.sol: Max Bets can't be 0.");
        maxBet = _maxBet;
    }

    // setup fee rate
    function setFeeRate(uint8 _feeRate) external whenPaused onlyOwner {
        require(_feeRate < 50, "CoinFlip.sol: Fee Rate can't be more than 50.");
        feeRate = _feeRate;
        emit FeeRate(feeRate);
    }

    // setup vault address
    function setVaultAddress(address _vaultAddress)
        external
        whenPaused
        onlyOwner
    {
        vault = IVault(_vaultAddress);
    }

    function createNewRoom(
        uint8 _rId,
        CoinFace _coinFace,
        uint128 _betAmount,
        uint256 _waitingTime
    ) external whenNotPaused nonReentrant {
        require(
            _rId > 0 && _rId <= maxRoom,
            "CoinFlip.sol: Room ID is out of range."
        );
        RoomInfo storage room = rooms[_rId];
        require(
            room.state == GameState.Ended,
            "CoinFlip.sol: Room is ongoing."
        );
        require(
            _betAmount >= minBet && _betAmount <= maxBet,
            "CoinFlip.sol: Bet amount must be more than minBet and less than maxBet."
        );

        vault.addGameBalance(msg.sender, _betAmount);

        room.betAmount = _betAmount;
        room.state = GameState.Waiting;
        room.expiredTime = block.timestamp + _waitingTime;
        room.gameId = ++gId;
        if (_coinFace == CoinFace.Head) {
            room.playerHead = msg.sender;
        } else {
            room.playerTail = msg.sender;
        }

        emit CreateNewRoom(
            _rId,
            msg.sender,
            room.betAmount,
            _coinFace,
            room.state,
            room.expiredTime,
            room.gameId
        );
    }

    function expiredRoom(uint8 _rId)
        external
        nonReentrant
        onlyWaitingRoom(_rId)
    {
        RoomInfo memory room = rooms[_rId];
        require(
            room.expiredTime <= block.timestamp,
            "CoinFlip.sol: Expired time doesn't reach."
        );

        address playerRefund;
        if (room.playerHead != address(0)) {
            playerRefund = room.playerHead;
        } else {
            playerRefund = room.playerTail;
        }

        vault.subGameBalance(playerRefund, room.betAmount, 0);

        delete (rooms[_rId]);

        emit ExpiredRoom(_rId, playerRefund, room.betAmount, room.gameId);
    }

    function joinRoom(uint8 _rId)
        external
        whenNotPaused
        nonReentrant
        onlyWaitingRoom(_rId)
    {
        RoomInfo storage room = rooms[_rId];
        require(
            room.expiredTime > block.timestamp,
            "CoinFlip.sol: Expired time reached."
        );
        require(
            room.playerHead != msg.sender && room.playerTail != msg.sender,
            "CoinFlip.sol: This player has already joined this room."
        );

        vault.addGameBalance(msg.sender, room.betAmount);

        if (room.playerHead != address(0)) {
            room.playerTail = msg.sender;
        } else {
            room.playerHead = msg.sender;
        }
        room.state = GameState.OnGoing;

        resolveRoom(_rId);

        emit JoinRoom(
            _rId,
            msg.sender,
            room.state,
            room.gameId,
            block.timestamp
        );
    }

    /**
     * Requests randomness
     */
    function getRandomNumber() internal returns (bytes32 requestId) {
        require(
            LINK.balanceOf(address(this)) > fee,
            "CoinFlip.sol: Not enough LINK - fill contract with faucet"
        );
        return requestRandomness(keyHash, fee);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        uint8 _rId = requests[requestId];
        RoomInfo storage room = rooms[_rId];
        results[_rId] = randomness;

        uint256 prob = randomness % 100; // use last 2 digit to estimate prob
        // if prob >= 50 then head
        CoinFace result;
        if (prob >= 50) {
            result = CoinFace.Head;
            room.winner = room.playerHead;
        } else {
            result = CoinFace.Tail;
            room.winner = room.playerTail;
        }

        uint128 betAmount = room.betAmount * 2;
        uint128 winnerBet = (betAmount * (100 - feeRate)) / 100;
        uint128 feeGame = betAmount - winnerBet;
        vault.subGameBalance(room.winner, winnerBet, feeGame);

        emit ResolveRoom(
            _rId,
            room.winner,
            winnerBet,
            feeGame,
            room.state,
            room.gameId,
            requestId,
            randomness
        );

        // case delete after get winner
        delete (rooms[_rId]);
    }

    function resolveRoom(uint8 _rId) internal {
        RoomInfo memory room = rooms[_rId];
        require(
            room.state == GameState.OnGoing,
            "CoinFlip.sol: Waiting for 2nd player."
        );

        bytes32 requestId = getRandomNumber();
        requests[requestId] = _rId;

        emit RequestedRandomness(requestId, _rId, room.gameId);
    }

    function emergencyEndGame(uint8 _rId) public onlyOwner {
        RoomInfo memory room = rooms[_rId];

        if (room.playerHead != address(0)) {
            vault.subGameBalance(room.playerHead, room.betAmount, 0);
        }
        if (room.playerTail != address(0)) {
            vault.subGameBalance(room.playerTail, room.betAmount, 0);
        }
        delete (rooms[_rId]);
    }

    function pause() external onlyRole(VAULT_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(VAULT_ROLE) {
        _unpause();
    }

    function isPlayerStillPlaying() external view returns (bool) {
        bool res = true;
        for (uint8 i = 0; i < maxRoom; i++) {
            RoomInfo storage info = rooms[i];
            if (
                info.state == GameState.Waiting ||
                info.state == GameState.OnGoing
            ) {
                return res;
            }
        }
        return false;
    }

    function withdrawLink() external onlyOwner {
        uint256 amount = LINK.balanceOf(address(this));
        require(amount > 0, "CoinFlip.sol: Not have LINK");
        LINK.transfer(owner(), amount);
    }

    receive() external payable {
        revert();
    }
}
