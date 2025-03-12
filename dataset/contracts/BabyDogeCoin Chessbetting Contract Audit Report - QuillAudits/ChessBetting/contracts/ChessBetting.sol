// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import '@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "./SafeOwnable.sol";


contract ChessBetting is EIP712, SafeOwnable {

    /* An ECDSA signature. */
    struct Sig {
        /* v parameter */
        uint8 v;
        /* r parameter */
        bytes32 r;
        /* s parameter */
        bytes32 s;
    }

    struct Withdrawal {
        address account;            //Address of the user, who's making withdrawal
        address token;              //Token address
        uint256 amount;             //Token amount to withdraw
        uint256 deadline;           //Deadline of the withdrawal validity
        uint256 nonce;              //nonce different order hash
    }

    struct Game {
        address account;            //Address of the user, who's playing the game
        address token;              //Token address
        uint256 betAmount;          //Bet amount
        uint256 gameId;             //Game ID
    }

    struct TokenData {
        address feeReceiver;
        uint64 feeAmount;   //in basis points
    }


    // game id => winner
    mapping(uint256 => address) public winners;
    // nonce => amount
    mapping(uint256 => uint256) public withdrawal;
    // user address => token address => tokenBalance
    mapping(address => mapping(address => uint256)) public balances;

    // token => fee receiver/ fee Amount
    mapping(address => TokenData) public tokenData;
    address public manager;
    bool public emergencyWithdrawalsAllowed = false;

    bytes32 constant WITHDRAWAL_TYPEHASH = keccak256(
        "Withdrawal(address account,address token,uint256 amount,uint256 deadline,uint256 nonce)"
    );

    bytes32 constant GAME_TYPEHASH = keccak256(
        "Game(address account,address token,uint256 betAmount,uint256 gameId)"
    );

    modifier onlyManager() {
        require(manager == _msgSender(), "Caller is not the manager");
        _;
    }

    event WithdrawalEvent (
        address account,
        address token,
        uint256 amount
    );

    event CompletedGame (
        uint256 gameId,
        address winner,
        address looser,
        address token,
        uint256 betAmount
    );

    event Deposit(address from, address token, uint256 amount);
    event TokenSet (address token, address feeReceiver, uint64 feeAmount);
    event TokenRemoved (address token);
    event ManagerSet(address);
    event EmergencyWithdrawalsEnabled();
    event EmergencyWithdrawalsDisabled();


    /*
     * @param token - Token address
     * @param _feeAmount - Fee amount in basis points
     * @param _tokenFeeReceiver - Fee receiver for the fee
     */
    constructor(
        address _token,
        uint64 _feeAmount,
        address _tokenFeeReceiver
    ) EIP712("Chess","1") {
        require(_feeAmount < 10000, "Over 10000");

        tokenData[_token].feeAmount = _feeAmount;
        tokenData[_token].feeReceiver = _tokenFeeReceiver;
    }


    /*
     * @param token - Token address
     * @param amount - Amount to deposit
     * @dev only Manager
     */
    function deposit(address token, uint256 amount) external {
        require(tokenData[token].feeReceiver != address(0), "Invalid token");
        require(amount > 0, "0 amount");

        address from = msg.sender;
        uint256 initialBalance = IERC20(token).balanceOf(address(this));

        IERC20(token).transferFrom(from, address(this), amount);

        uint256 subsequentBalance = IERC20(token).balanceOf(address(this));
        balances[from][token] += subsequentBalance - initialBalance;
        emit Deposit(from, token, subsequentBalance - initialBalance);
    }


    /*
     * @param winner - Winner
     * @param _gameData1 - Game data of player 1
     * @param _gameData2 - Game data of player 2
     * @param _sig1 - Signature of player 1
     * @param _sig2 - Signature of player 2
     * @dev only Manager
     */
    function setWinner(
        address winner,
        Game calldata _gameData1,
        Game calldata _gameData2,
        Sig calldata _sig1,
        Sig calldata _sig2
    ) external onlyManager {
        {
            bytes32 hash1 = buildGameHash(_gameData1);
            (address recoveredAddress1, ) = ECDSA.tryRecover(hash1, _sig1.v, _sig1.r, _sig1.s);
            require(_gameData1.account == recoveredAddress1, 'Bad signature');

            bytes32 hash2 = buildGameHash(_gameData2);
            (address recoveredAddress2, ) = ECDSA.tryRecover(hash2, _sig2.v, _sig2.r, _sig2.s);
            require(_gameData2.account == recoveredAddress2, 'Bad signature');
        }
        require(_gameData1.gameId == _gameData2.gameId, "Invalid gameId");
        require(_gameData1.betAmount == _gameData2.betAmount, "Invalid bet amount");
        address feeReceiver = tokenData[_gameData1.token].feeReceiver;
        require(_gameData1.token == _gameData2.token
            && feeReceiver != address(0), "Invalid token");

        require(winners[_gameData1.gameId] == address(0), "Winner already selected");
        require(_gameData1.account == winner || _gameData2.account == winner, "No such player");
        require(_gameData1.betAmount <= balances[_gameData1.account][_gameData1.token]
            && _gameData2.betAmount <= balances[_gameData2.account][_gameData2.token], "Not enough balance");

        uint256 betAmount = _gameData1.betAmount;
        uint256 feeAmount = betAmount * tokenData[_gameData1.token].feeAmount / 10000;
        uint256 prize = betAmount - feeAmount;

        balances[winner][_gameData1.token] += prize;
        winners[_gameData1.gameId] = winner;

        address looser = winner == _gameData1.account ? _gameData2.account : _gameData1.account;
        balances[looser][_gameData1.token] -= betAmount;

        IERC20(_gameData1.token).transfer(feeReceiver, feeAmount);

        emit CompletedGame(
            _gameData1.gameId,
            winner,
            looser,
            _gameData1.token,
            _gameData1.betAmount
        );
    }


    /*
     * @param feeAmount - amount of tokens to take as a fee
     * @param _withdrawal - Withdrawal data
     * @param _sig - Signature
     * @dev only Manager
     */
    function withdraw(
        uint256 feeAmount,
        Withdrawal calldata _withdrawal,
        Sig calldata _sig
    ) external onlyManager {
        require(tokenData[_withdrawal.token].feeReceiver != address(0), "Invalid token");
        require(withdrawal[_withdrawal.nonce] == 0, "Already withdrawn");

        uint256 amount = _withdrawal.amount;
        address account = _withdrawal.account;
        bytes32 hash = buildWithdrawalHash(_withdrawal);
        (address recoveredAddress, ) = ECDSA.tryRecover(hash, _sig.v, _sig.r, _sig.s);
        require(account == recoveredAddress, 'Bad signature');
        require(block.timestamp <= _withdrawal.deadline, "Outdated!");

        IERC20 token = IERC20(_withdrawal.token);

        require(amount > 0 && amount <= balances[account][address(token)], "Invalid amount");

        withdrawal[_withdrawal.nonce] = amount;
        balances[account][address(token)] -= amount;

        token.transfer(account, amount - feeAmount);
        token.transfer(msg.sender, feeAmount);

        emit WithdrawalEvent(account, address(token), amount);
    }


    /*
     * @notice Emergency withdraw deposited by msg.sender tokens
     * @param token ERC20 token address
     * @dev In case something happens to Front End or manager approach, owner will allow anyone to emergency withdraw their deposits
     */
    function emergencyWithdraw(IERC20 token) external {
        require(emergencyWithdrawalsAllowed, "Not allowed");

        uint256 amount = balances[msg.sender][address(token)];
        require(amount > 0, "Nothing to withdraw");
        balances[msg.sender][address(token)] = 0;

        token.transfer(msg.sender, amount);

        emit WithdrawalEvent(msg.sender, address(token), amount);
    }


    /*
     * @notice Function builds hash according to hashing typed data standard V4 (EIP712)
     * @param _withdrawal - Withdrawal info
     * @dev May be used on off-chain to build order hash
     */
    function buildWithdrawalHash(Withdrawal calldata _withdrawal) public view returns (bytes32){
        return _hashTypedDataV4(keccak256(abi.encode(
                WITHDRAWAL_TYPEHASH,
                _withdrawal.account,
                _withdrawal.token,
                _withdrawal.amount,
                _withdrawal.deadline,
                _withdrawal.nonce
            )));
    }

    /*
     * @notice Function builds hash according to hashing typed data standard V4 (EIP712)
     * @param _game - Game info
     * @dev May be used on off-chain to build order hash
     */
    function buildGameHash(Game calldata _game) public view returns (bytes32){
        return _hashTypedDataV4(keccak256(abi.encode(
                GAME_TYPEHASH,
                _game.account,
                _game.token,
                _game.betAmount,
                _game.gameId
            )));
    }


    /*
     * @param _manager - New Game manager
     * @dev only Owner
     */
    function setManager(address _manager) external onlyOwner{
        require(manager != _manager, "Already set");
        require(address(0) != _manager, "Invalid address");
        manager = _manager;

        emit ManagerSet(_manager);
    }


    /*
     * @notice Allows emergency withdrawals
     * @dev only Owner
     */
    function enableEmergencyWithdrawals() external onlyOwner{
        emergencyWithdrawalsAllowed = true;

        emit EmergencyWithdrawalsEnabled();
    }


    /*
     * @notice Disallows emergency withdrawals
     * @dev only Owner
     */
    function disableEmergencyWithdrawals() external onlyOwner{
        emergencyWithdrawalsAllowed = false;

        emit EmergencyWithdrawalsDisabled();
    }


    /*
     * @param _token - ERC20 token address
     * @param _feeReceiver - Fee receiver for this token
     * @param _feeAmount - Fee amount in basis points
     * @dev only Owner
     */
    function setTokenData(
        address _token,
        address _feeReceiver,
        uint64 _feeAmount
    ) external onlyOwner{
        require(tokenData[_token].feeReceiver != _feeReceiver, "Already set");
        require(_feeAmount < 10000, "Over 10000");

        tokenData[_token] = TokenData({
            feeReceiver: _feeReceiver,
            feeAmount: _feeAmount
        });

        emit TokenSet(_token, _feeReceiver, _feeAmount);
    }

    /*
     * @notice Blocks token from being used
     * @param _token - ERC20 token address
     * @dev only Owner
     */
    function removeToken(
        address _token
    ) external onlyOwner {
        tokenData[_token] = TokenData({
            feeReceiver: address(0),
            feeAmount: uint64(0)
        });

        emit TokenRemoved(_token);
    }
}