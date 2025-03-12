//contracts/BinaryOption.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./interfaces/AggregatorV3Interface.sol";

contract BinaryOption is Ownable, Pausable, ReentrancyGuard {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  ERC20 public immutable betToken;
  AggregatorV3Interface public oracle;
  bool public genesisLockOnce = false;
  bool public genesisStartOnce = false;

  address public adminAddress; // address of the admin
  address public operatorAddress; // address of the operator

  uint256 public bufferSeconds; // number of seconds for valid execution of a bet round
  uint256 public intervalSeconds; // interval in seconds for each round
  uint256 public lockInSeconds; // number of seconds before round locked

  uint256 public minBetAmount; // minimum betting amount (denominated in wei)
  uint256 public treasuryFee; // treasury rate (e.g. 200 = 2%, 150 = 1.50%)
  uint256 public treasuryAmount; // treasury amount that was not claimed

  uint256 public currentEpoch; // current epoch for bet round

  uint256 public oracleLatestRoundId; // converted from uint80 (Chainlink)
  uint256 public oracleUpdateAllowance; // seconds

  uint256 public constant MAX_TREASURY_FEE = 1000; // 10%

  mapping(uint256 => mapping(address => BetInfo)) public ledger;
  mapping(uint256 => Round) public rounds;
  mapping(address => uint256[]) public userRounds;

  enum Position {
    High,
    Low
  }

  struct Round {
    uint256 epoch;
    uint256 startTimestamp;
    uint256 lockTimestamp;
    uint256 closeTimestamp;
    int256 lockPrice;
    int256 closePrice;
    uint256 lockOracleId;
    uint256 closeOracleId;
    uint256 totalAmount;
    uint256 highAmount;
    uint256 lowAmount;
    uint256 rewardBaseCalAmount;
    uint256 rewardAmount;
    bool oracleCalled;
  }

  struct BetInfo {
    Position position;
    uint256 amount;
    bool claimed; // default false
  }

  /**
   * @notice Constructor
   * @param _oracleAddress: oracle address
   * @param _adminAddress: admin address
   * @param _operatorAddress: operator address
   * @param _intervalSeconds: number of time within an interval
   * @param _bufferSeconds: buffer of time for resolution of price
   * @param _minBetAmount: minimum bet amounts (in wei)
   * @param _oracleUpdateAllowance: oracle update allowance
   * @param _treasuryFee: treasury fee (1000 = 10%)
   * @param _lockInSeconds:
   */
  constructor(
    ERC20 _betToken,
    address _oracleAddress,
    address _adminAddress,
    address _operatorAddress,
    uint256 _intervalSeconds,
    uint256 _bufferSeconds,
    uint256 _minBetAmount,
    uint256 _oracleUpdateAllowance,
    uint256 _treasuryFee,
    uint256 _lockInSeconds
  ) {
    require(_treasuryFee <= MAX_TREASURY_FEE, "BinaryOption: Treasury fee too high");

    betToken = _betToken;
    oracle = AggregatorV3Interface(_oracleAddress);
    adminAddress = _adminAddress;
    operatorAddress = _operatorAddress;
    intervalSeconds = _intervalSeconds;
    bufferSeconds = _bufferSeconds;
    minBetAmount = _minBetAmount;
    oracleUpdateAllowance = _oracleUpdateAllowance;
    treasuryFee = _treasuryFee;
    lockInSeconds = _lockInSeconds;
  }

  event StartRound(uint256 indexed epoch);
  event LockRound(uint256 indexed epoch, uint256 indexed roundId, int256 price);
  event EndRound(uint256 indexed epoch, uint256 indexed roundId, int256 price);
  event BetLow(address indexed sender, uint256 indexed epoch, uint256 amount);
  event BetHigh(address indexed sender, uint256 indexed epoch, uint256 amount);
  event Claim(address indexed sender, uint256 indexed epoch, uint256 amount);
  event RewardsCalculated(
    uint256 indexed epoch,
    uint256 rewardBaseCalAmount,
    uint256 rewardAmount,
    uint256 treasuryAmount
  );

  event NewAdminAddress(address admin);
  event NewOperatorAddress(address operator);
  event NewBufferIntervalAndLockInSeconds(uint256 bufferSeconds, uint256 intervalSeconds, uint256 lockInSeconds);
  event NewMinBetAmount(uint256 indexed epoch, uint256 minBetAmount);
  event NewOracle(address oracle);
  event NewOracleUpdateAllowance(uint256 oracleUpdateAllowance);
  event NewTreasuryFee(uint256 indexed epoch, uint256 treasuryFee);

  event Pause(uint256 indexed epoch);
  event Unpause(uint256 indexed epoch);
  event TokenRecovery(address indexed token, uint256 amount);
  event TreasuryClaim(uint256 amount);

  modifier onlyAdmin() {
    require(msg.sender == adminAddress, "BinaryOption: not admin");
    _;
  }

  modifier onlyAdminOrOperator() {
    require(msg.sender == adminAddress || msg.sender == operatorAddress, "BinaryOption: not operator/admin");
    _;
  }

  modifier onlyOperator() {
    require(msg.sender == operatorAddress, "BinaryOption: not operator");
    _;
  }

  modifier notContract() {
    require(!_isContract(msg.sender), "BinaryOption: contract not allowed");
    require(msg.sender == tx.origin, "BinaryOption: proxy contract not allowed");
    _;
  }

  /**
   * @notice Bet Low position
   * @param _epoch: epoch
   * @param _amount: amount
   */
  function betLow(uint256 _epoch, uint256 _amount) external whenNotPaused nonReentrant notContract {
    require(_epoch == currentEpoch, "BinaryOption: Bet is too early/late");
    require(_bettable(_epoch), "BinaryOption: Round not bettable");
    require(_amount >= minBetAmount, "BinaryOption: Bet amount must be greater than minBetAmount");
    require(ledger[_epoch][msg.sender].amount == 0, "BinaryOption: Can only bet once per round");

    // Update round data
    uint256 preAmount = betToken.balanceOf(address(this));
    betToken.safeTransferFrom(msg.sender, address(this), _amount);
    uint256 postDeposit = betToken.balanceOf(address(this));
    uint256 actualAmount = postDeposit.sub(preAmount);
    Round storage round = rounds[_epoch];
    round.totalAmount = round.totalAmount + actualAmount;
    round.lowAmount = round.lowAmount + actualAmount;

    // Update user data
    BetInfo storage betInfo = ledger[_epoch][msg.sender];
    betInfo.position = Position.Low;
    betInfo.amount = actualAmount;
    userRounds[msg.sender].push(_epoch);

    emit BetLow(msg.sender, _epoch, actualAmount);
  }

  /**
   * @notice Bet High position
   * @param _epoch: epoch
   * @param _amount: amount
   */
  function betHigh(uint256 _epoch, uint256 _amount) external whenNotPaused nonReentrant notContract {
    require(_epoch == currentEpoch, "BinaryOption: Bet is too early/late");
    require(_bettable(_epoch), "BinaryOption: Round not bettable");
    require(_amount >= minBetAmount, "BinaryOption: Bet amount must be greater than minBetAmount");
    require(ledger[_epoch][msg.sender].amount == 0, "BinaryOption: Can only bet once per round");

    // Update round data
    uint256 preAmount = betToken.balanceOf(address(this));
    betToken.safeTransferFrom(msg.sender, address(this), _amount);
    uint256 postDeposit = betToken.balanceOf(address(this));
    uint256 actualAmount = postDeposit.sub(preAmount);
    Round storage round = rounds[_epoch];
    round.totalAmount = round.totalAmount + actualAmount;
    round.highAmount = round.highAmount + actualAmount;

    // Update user data
    BetInfo storage betInfo = ledger[_epoch][msg.sender];
    betInfo.position = Position.High;
    betInfo.amount = actualAmount;
    userRounds[msg.sender].push(_epoch);

    emit BetHigh(msg.sender, _epoch, actualAmount);
  }

  /**
   * @notice Claim reward for an array of epochs
   * @param epochs: array of epochs
   */
  function claim(uint256[] calldata epochs) external nonReentrant notContract {
    uint256 reward; // Initializes reward

    for (uint256 i = 0; i < epochs.length; i++) {
      require(rounds[epochs[i]].startTimestamp != 0, "BinaryOption: Round has not started");
      require(block.timestamp > rounds[epochs[i]].closeTimestamp + bufferSeconds, "BinaryOption: Round has not ended");

      uint256 addedReward = 0;

      // Round valid, claim rewards
      if (rounds[epochs[i]].oracleCalled) {
        require(claimable(epochs[i], msg.sender), "BinaryOption: Not eligible for claim");
        Round memory round = rounds[epochs[i]];
        addedReward = (ledger[epochs[i]][msg.sender].amount * round.rewardAmount) / round.rewardBaseCalAmount;
      }
      // Round invalid, refund bet amount
      else {
        require(refundable(epochs[i], msg.sender), "BinaryOption: Not eligible for refund");
        addedReward = ledger[epochs[i]][msg.sender].amount;
      }

      ledger[epochs[i]][msg.sender].claimed = true;
      reward += addedReward;

      emit Claim(msg.sender, epochs[i], addedReward);
    }

    if (reward > 0) {
      betToken.safeTransfer(address(msg.sender), reward);
    }
  }

  /**
   * @notice Set Oracle address
   * @dev Callable by admin
   */
  function setOracle(address _oracle) external whenPaused onlyAdmin {
    require(_oracle != address(0), "BinaryOption: Cannot be zero address");
    oracleLatestRoundId = 0;
    oracle = AggregatorV3Interface(_oracle);

    // Dummy check to make sure the interface implements this function properly
    oracle.latestRoundData();

    emit NewOracle(_oracle);
  }

  /**
   * @notice Set oracle update allowance
   * @dev Callable by admin
   */
  function setOracleUpdateAllowance(uint256 _oracleUpdateAllowance) external whenPaused onlyAdmin {
    oracleUpdateAllowance = _oracleUpdateAllowance;

    emit NewOracleUpdateAllowance(_oracleUpdateAllowance);
  }

  /**
   * @notice Determine if a round is valid for receiving bets
   * Round must have started and locked
   * Current timestamp must be within startTimestamp and closeTimestamp
   */
  function _bettable(uint256 epoch) internal view returns (bool) {
    return
      rounds[epoch].startTimestamp != 0 &&
      rounds[epoch].lockTimestamp != 0 &&
      block.timestamp > rounds[epoch].startTimestamp &&
      block.timestamp < rounds[epoch].lockTimestamp;
  }

  /**
   * @notice Get latest recorded price from oracle
   * If it falls below allowed buffer or has not updated, it would be invalid.
   */
  function _getPriceFromOracle() internal view returns (uint80, int256) {
    uint256 leastAllowedTimestamp = block.timestamp + oracleUpdateAllowance;
    (uint80 roundId, int256 price, , uint256 timestamp, ) = oracle.latestRoundData();
    require(timestamp <= leastAllowedTimestamp, "BinaryOption: Oracle update exceeded max timestamp allowance");
    require(
      uint256(roundId) > oracleLatestRoundId,
      "BinaryOption: Oracle update roundId must be larger than oracleLatestRoundId"
    );
    return (roundId, price);
  }

  /**
   * @notice Lock round
   * @param epoch: epoch
   * @param roundId: roundId
   * @param price: price of the round
   */
  function _safeLockRound(
    uint256 epoch,
    uint256 roundId,
    int256 price
  ) internal {
    require(rounds[epoch].startTimestamp != 0, "BinaryOption: Can only lock round after round has started");
    require(block.timestamp >= rounds[epoch].lockTimestamp, "BinaryOption: Can only lock round after lockTimestamp");
    require(
      block.timestamp <= rounds[epoch].lockTimestamp + bufferSeconds,
      "BinaryOption: Can only lock round within bufferSeconds"
    );
    Round storage round = rounds[epoch];
    round.lockPrice = price;
    round.lockOracleId = roundId;

    emit LockRound(epoch, roundId, round.lockPrice);
  }

  /**
   * @notice Calculate rewards for round
   * @param epoch: epoch
   */
  function _calculateRewards(uint256 epoch) internal {
    require(
      rounds[epoch].rewardBaseCalAmount == 0 && rounds[epoch].rewardAmount == 0,
      "BinaryOption: Rewards calculated"
    );
    Round storage round = rounds[epoch];
    uint256 rewardBaseCalAmount;
    uint256 treasuryAmt;
    uint256 rewardAmount;

    // high wins
    if (round.closePrice > round.lockPrice) {
      rewardBaseCalAmount = round.highAmount;
      treasuryAmt = (round.totalAmount * treasuryFee) / 10000;
      rewardAmount = round.totalAmount - treasuryAmt;
    }
    // low wins
    else if (round.closePrice < round.lockPrice) {
      rewardBaseCalAmount = round.lowAmount;
      treasuryAmt = (round.totalAmount * treasuryFee) / 10000;
      rewardAmount = round.totalAmount - treasuryAmt;
    }
    // House wins
    else {
      rewardBaseCalAmount = 0;
      rewardAmount = 0;
      treasuryAmt = round.totalAmount;
    }
    round.rewardBaseCalAmount = rewardBaseCalAmount;
    round.rewardAmount = rewardAmount;

    // Add to treasury
    treasuryAmount += treasuryAmt;

    emit RewardsCalculated(epoch, rewardBaseCalAmount, rewardAmount, treasuryAmt);
  }

  /**
   * @notice End round
   * @param epoch: epoch
   * @param roundId: roundId
   * @param price: price of the round
   */
  function _safeEndRound(
    uint256 epoch,
    uint256 roundId,
    int256 price
  ) internal {
    require(rounds[epoch].lockTimestamp != 0, "BinaryOption: Can only end round after round has locked");
    require(block.timestamp >= rounds[epoch].closeTimestamp, "BinaryOption: Can only end round after closeTimestamp");
    require(
      block.timestamp <= rounds[epoch].closeTimestamp + bufferSeconds,
      "BinaryOption: Can only end round within bufferSeconds"
    );
    Round storage round = rounds[epoch];
    round.closePrice = price;
    round.closeOracleId = roundId;
    round.oracleCalled = true;
    emit EndRound(epoch, roundId, round.closePrice);
  }

  /**
   * @notice Start genesis round
   * @dev Callable by admin or operator
   */
  function genesisStartRound() external whenNotPaused onlyOperator {
    require(!genesisStartOnce, "BinaryOption: Can only run genesisStartRound once");

    currentEpoch = currentEpoch + 1;
    _startRound(currentEpoch);
    genesisStartOnce = true;
  }

  /**
   * @notice Lock genesis round
   * @dev Callable by operator
   */
  function genesisLockRound() external whenNotPaused onlyOperator {
    require(genesisStartOnce, "BinaryOption: Can only run after genesisStartRound is triggered");
    require(!genesisLockOnce, "BinaryOption: Can only run genesisLockRound once");

    (uint80 currentRoundId, int256 currentPrice) = _getPriceFromOracle();

    oracleLatestRoundId = uint256(currentRoundId);

    _safeLockRound(currentEpoch, currentRoundId, currentPrice);

    currentEpoch = currentEpoch + 1;
    _startRound(currentEpoch);
    genesisLockOnce = true;
  }

  /**
   * @notice Start the next round n, lock price for round n-1, end round n-2
   * @dev Callable by operator
   */
  function lockAndStartNextRound() external whenNotPaused onlyOperator {
    require(
      genesisStartOnce && genesisLockOnce,
      "BinaryOption: Can only run after genesisStartRound and genesisLockRound is triggered"
    );

    (uint80 currentRoundId, int256 currentPrice) = _getPriceFromOracle();

    oracleLatestRoundId = uint256(currentRoundId);

    // CurrentEpoch refers to previous round (n-1)
    _safeLockRound(currentEpoch, currentRoundId, currentPrice);

    // Increment currentEpoch to current round (n)
    currentEpoch = currentEpoch + 1;
    _startRound(currentEpoch);
  }

  /**
   * @notice End round
   * @dev Callable by operator
   */
  function endRound() external whenNotPaused onlyOperator {
    require(
      genesisStartOnce && genesisLockOnce,
      "BinaryOption: Can only run after genesisStartRound and genesisLockRound is triggered"
    );

    (uint80 currentRoundId, int256 currentPrice) = _getPriceFromOracle();

    _safeEndRound(currentEpoch - 1, currentRoundId, currentPrice);
    _calculateRewards(currentEpoch - 1);
    claimTreasury();
  }

  /**
   * @notice called by the admin to pause, triggers stopped state
   * @dev Callable by admin or operator
   */
  function pause() external whenNotPaused onlyAdminOrOperator {
    _pause();

    emit Pause(currentEpoch);
  }

  /**
   * @notice called by the admin to unpause, returns to normal state
   * Reset genesis state. Once paused, the rounds would need to be kickstarted by genesis
   */
  function unpause() external whenPaused onlyAdmin {
    genesisStartOnce = false;
    genesisLockOnce = false;
    _unpause();

    emit Unpause(currentEpoch);
  }

  /**
   * @notice Claim all rewards in treasury
   * @dev Callable by admin
   */
  function claimTreasury() public nonReentrant onlyAdminOrOperator {
    uint256 currentTreasuryAmount = treasuryAmount;
    treasuryAmount = 0;
    betToken.safeTransfer(adminAddress, currentTreasuryAmount);

    emit TreasuryClaim(currentTreasuryAmount);
  }

  /**
   * @notice It allows the owner to recover tokens sent to the contract by mistake
   * @param _token: token address
   * @param _amount: token amount
   * @dev Callable by owner
   */
  function recoverToken(address _token, uint256 _amount) external onlyOwner {
    require(_token != address(betToken), "BinaryOption: cannot recover bet token");

    ERC20(_token).safeTransfer(address(msg.sender), _amount);

    emit TokenRecovery(_token, _amount);
  }

  /**
   * @notice Set buffer, interval and lock (in seconds)
   * @dev Callable by admin
   */
  function setBufferIntervalAndLockInSeconds(
    uint256 _bufferSeconds,
    uint256 _intervalSeconds,
    uint256 _lockInSeconds
  ) external whenPaused onlyAdmin {
    require(_bufferSeconds < _intervalSeconds, "BinaryOption: bufferSeconds must be lower than intervalSeconds");
    require(_bufferSeconds < _lockInSeconds, "BinaryOption: bufferSeconds must be lower than lockInSeconds");
    require(_lockInSeconds < _intervalSeconds, "BinaryOption: lockInSeconds must be lower than intervalSeconds");
    bufferSeconds = _bufferSeconds;
    intervalSeconds = _intervalSeconds;
    lockInSeconds = _lockInSeconds;

    emit NewBufferIntervalAndLockInSeconds(_bufferSeconds, _intervalSeconds, _lockInSeconds);
  }

  /**
   * @notice Set minBetAmount
   * @dev Callable by admin
   */
  function setMinBetAmount(uint256 _minBetAmount) external whenPaused onlyAdmin {
    require(_minBetAmount != 0, "BinaryOption: must be greater than 0");
    minBetAmount = _minBetAmount;

    emit NewMinBetAmount(currentEpoch, minBetAmount);
  }

  /**
   * @notice Set treasury fee
   * @dev Callable by admin
   */
  function setTreasuryFee(uint256 _treasuryFee) external whenPaused onlyAdmin {
    require(_treasuryFee <= MAX_TREASURY_FEE, "BinaryOption: treasury fee too high");
    treasuryFee = _treasuryFee;

    emit NewTreasuryFee(currentEpoch, treasuryFee);
  }

  /**
   * @notice Set operator address
   * @dev Callable by admin
   */
  function setOperator(address _operatorAddress) external onlyAdmin {
    require(_operatorAddress != address(0), "BinaryOption: cannot be zero address");
    operatorAddress = _operatorAddress;

    emit NewOperatorAddress(_operatorAddress);
  }

  /**
   * @notice Set admin address
   * @dev Callable by owner
   */
  function setAdmin(address _adminAddress) external onlyOwner {
    require(_adminAddress != address(0), "BinaryOption: cannot be zero address");
    adminAddress = _adminAddress;

    emit NewAdminAddress(_adminAddress);
  }

  /**
   * @notice Returns round epochs and bet information for a user that has participated
   * @param user: user address
   * @param cursor: cursor
   * @param size: size
   */
  function getUserRounds(
    address user,
    uint256 cursor,
    uint256 size
  )
    external
    view
    returns (
      uint256[] memory,
      BetInfo[] memory,
      uint256
    )
  {
    uint256 length = size;

    if (length > userRounds[user].length - cursor) {
      length = userRounds[user].length - cursor;
    }

    uint256[] memory values = new uint256[](length);
    BetInfo[] memory betInfo = new BetInfo[](length);

    for (uint256 i = 0; i < length; i++) {
      values[i] = userRounds[user][cursor + i];
      betInfo[i] = ledger[values[i]][user];
    }

    return (values, betInfo, cursor + length);
  }

  /**
   * @notice Returns round epochs length
   * @param user: user address
   */
  function getUserRoundsLength(address user) external view returns (uint256) {
    return userRounds[user].length;
  }

  /**
   * @notice Get the claimable stats of specific epoch and user account
   * @param epoch: epoch
   * @param user: user address
   */
  function claimable(uint256 epoch, address user) public view returns (bool) {
    BetInfo memory betInfo = ledger[epoch][user];
    Round memory round = rounds[epoch];
    if (round.lockPrice == round.closePrice) {
      return false;
    }
    return
      round.oracleCalled &&
      betInfo.amount != 0 &&
      !betInfo.claimed &&
      ((round.closePrice > round.lockPrice && betInfo.position == Position.High) ||
        (round.closePrice < round.lockPrice && betInfo.position == Position.Low));
  }

  /**
   * @notice Get the refundable stats of specific epoch and user account
   * @param epoch: epoch
   * @param user: user address
   */
  function refundable(uint256 epoch, address user) public view returns (bool) {
    BetInfo memory betInfo = ledger[epoch][user];
    Round memory round = rounds[epoch];
    return
      !round.oracleCalled &&
      !betInfo.claimed &&
      block.timestamp > round.closeTimestamp + bufferSeconds &&
      betInfo.amount != 0;
  }

  /**
   * @notice Start round
   * @param epoch: epoch
   */
  function _startRound(uint256 epoch) internal {
    Round storage round = rounds[epoch];
    round.startTimestamp = block.timestamp;
    round.lockTimestamp = block.timestamp + lockInSeconds;
    round.closeTimestamp = block.timestamp + intervalSeconds;
    round.epoch = epoch;
    round.totalAmount = 0;

    emit StartRound(epoch);
  }

  /**
   * @notice Returns true if `account` is a contract.
   * @param account: account address
   */
  function _isContract(address account) internal view returns (bool) {
    uint256 size;
    assembly {
      size := extcodesize(account)
    }
    return size > 0;
  }
}
