// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import "hardhat/console.sol";

import "./interfaces/IMasterchef.sol";
import "./interfaces/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PredictionPool is ReentrancyGuard, Ownable {
  using SafeERC20 for IERC20;

  uint256 public constant PRECISION = 1e12;
  uint256 public depositDuration = 1 days;
  uint256 public lockDuration = 6 days;
  uint256 public withdrawFee = 500; // /10000
  address public devAddress = 0x1F63c3213c0441CDB8edb009289E4c0Da6D81156;

  IMasterchef public immutable masterchef;
  IERC20 public immutable dpt;
  IERC20 public immutable cake;
  AggregatorV3Interface public immutable aggregator;
  address public immutable upkeeper;

  uint256 public dptPerBlock;

  uint256[5] public dptRewardRate = [50, 20, 15, 10, 5];

  mapping(address => uint256) public userDptReward; // user address => dpt reward

  uint256 public cakeInterest;

  struct UserInfo {
    uint256 longAmount;
    uint256 shortAmount;
    uint256 rewardStakingDebt;
    uint256 cakeDebt;
  }

  mapping(uint256 => mapping(address => UserInfo)) public userInfo; // pid => user address => user info

  struct PoolInfo {
    IERC20 lpToken;
    uint256 poolIdPancake;
    uint256 allocPoint;
    uint256 cakePerLong;
    uint256 cakePerShort;
    uint256 totalLongSupply;
    uint256 totalShortSupply;
    uint256 accStakingRewardPerShare;
    uint256 lastStakingRewardBlock;
    uint256 canYieldCake;
  }

  struct GameStatus {
    bool isStartedFirstRound;
    bool isLocking;
    bool isShortWinLastRound;
    int256 initialPrice;
    uint256 lastUpdatedAt;
  }

  GameStatus public status;

  uint256 public totalAllocPoint;

  PoolInfo[] public pools;

  event AddPool(
    address indexed lpToken,
    uint256 indexed poolId,
    uint256 indexed poolIdPancake,
    uint256 allocPoint
  );

  event StartFirstRound(int256 initialPrice);

  event Deposit(
    address indexed sender,
    uint256 indexed poolId,
    uint256 longAmount,
    uint256 shortAmount
  );

  event Withdraw(
    address indexed sender,
    uint256 indexed poolId,
    uint256 longAmount,
    uint256 shortAmount
  );

  event Lock(uint256 dptPerBlock);

  event EndGame(
    bool isShortWinner,
    uint256 totalCakeGet,
    int256 endPrice,
    address[] randomUser,
    int256 initialPrice
  );

  event SetMultiplier(
    uint256 indexed poolId,
    uint256 oldAllocPoint,
    uint256 newAllocPoint
  );

  event SetDepositDuration(uint256 oldValue, uint256 newValue);
  event SetLockDuration(uint256 oldValue, uint256 newValue);
  event SetWithdrawFee(uint256 oldValue, uint256 newValue);
  event SetDevAddress(address oldValue, address newValue);

  constructor(
    address _chef,
    address _dpt,
    address _cake,
    address _aggregator,
    address _upkeeper
  ) {
    require(_chef != address(0), "chef is a zero address");
    require(_dpt != address(0), "dpt is a zero address");
    require(_cake != address(0), "cake is a zero address");
    require(_aggregator != address(0), "aggregator is a zero address");
    require(_upkeeper != address(0), "upkeeper is a zero address");
    masterchef = IMasterchef(_chef);
    dpt = IERC20(_dpt);
    cake = IERC20(_cake);
    aggregator = AggregatorV3Interface(_aggregator);
    upkeeper = _upkeeper;

    status.isLocking = true;
  }

  function getMultiplier(uint256 _lastRewardBlock)
    private
    view
    returns (uint256)
  {
    if (!status.isLocking) {
      return 0;
    }
    return block.number - _lastRewardBlock;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyUpkeeper() {
    require(upkeeper == msg.sender, "caller is not the upkeeper");
    _;
  }

  function setDepositDuration(uint256 _depositDuration) external onlyOwner {
    uint256 oldValue = depositDuration;
    depositDuration = _depositDuration;
    emit SetDepositDuration(oldValue, _depositDuration);
  }

  function setLockDuration(uint256 _lockDuration) external onlyOwner {
    uint256 oldValue = lockDuration;
    lockDuration = _lockDuration;
    emit SetLockDuration(oldValue, _lockDuration);
  }

  function setWithdrawFee(uint256 _withdrawFee) external onlyOwner {
    uint256 oldValue = withdrawFee;
    withdrawFee = _withdrawFee;
    emit SetWithdrawFee(oldValue, _withdrawFee);
  }

  function setDevAddress(address _dev) external onlyOwner {
    address oldValue = devAddress;
    devAddress = _dev;
    emit SetDevAddress(oldValue, _dev);
  }

  function add(
    uint256 _allocPoint,
    uint256 _poolIdPancake,
    address _lpToken,
    uint256 _canYieldCake
  ) external onlyOwner {
    totalAllocPoint += _allocPoint;
    pools.push(
      PoolInfo({
        lpToken: IERC20(_lpToken),
        poolIdPancake: _poolIdPancake,
        allocPoint: _allocPoint,
        cakePerLong: 0,
        cakePerShort: 0,
        totalLongSupply: 0,
        totalShortSupply: 0,
        lastStakingRewardBlock: 0,
        accStakingRewardPerShare: 0,
        canYieldCake: _canYieldCake
      })
    );

    if (_canYieldCake == 1) {
      IERC20(_lpToken).safeIncreaseAllowance(
        address(masterchef),
        type(uint256).max
      );
    }

    emit AddPool(_lpToken, pools.length - 1, _poolIdPancake, _allocPoint);
  }

  function _getPrice() private view returns (int256) {
    (
      uint80 roundID,
      int256 price,
      uint256 startedAt,
      uint256 timeStamp,
      uint80 answeredInRound
    ) = aggregator.latestRoundData();
    return price;
  }

  function getPoolsLength() external view returns (uint256) {
    return pools.length;
  }

  function startFirstRound() external onlyOwner {
    require(pools.length > 0, "empty pools");
    require(!status.isStartedFirstRound, "already started");

    status.isStartedFirstRound = true;
    status.initialPrice = _getPrice();
    status.isLocking = false;
    status.lastUpdatedAt = block.timestamp;

    emit StartFirstRound(status.initialPrice);
  }

  function increaseAllowancePancake(uint256 poolId) external onlyOwner {
    uint256 currentAllowance = pools[poolId].lpToken.allowance(
      address(this),
      address(masterchef)
    );

    pools[poolId].lpToken.safeIncreaseAllowance(
      address(masterchef),
      type(uint256).max - currentAllowance
    );
  }

  function updatePool(uint256 poolId) private {
    PoolInfo storage pool = pools[poolId];

    if (block.number <= pool.lastStakingRewardBlock) {
      return;
    }

    uint256 totalSupply = pool.totalLongSupply + pool.totalShortSupply;
    if (totalSupply == 0) {
      pool.lastStakingRewardBlock = block.number;
      return;
    }
    uint256 multiplier = getMultiplier(pool.lastStakingRewardBlock);

    if (multiplier > 0) {
      uint256 dptReward = (multiplier * dptPerBlock * pool.allocPoint) /
        totalAllocPoint;

      pool.accStakingRewardPerShare += ((dptReward * PRECISION) / totalSupply);

      pool.lastStakingRewardBlock = block.number;
    }
  }

  function setMultiplier(uint256 _pid, uint256 _newAllocPoint)
    external
    onlyOwner
  {
    require(!status.isLocking, "should not set when locking");
    uint256 length = pools.length;
    for (uint256 i = 0; i < length; i++) {
      updatePool(i);
    }
    uint256 oldAllocPoint = pools[_pid].allocPoint;
    totalAllocPoint = totalAllocPoint - oldAllocPoint + _newAllocPoint;
    pools[_pid].allocPoint = _newAllocPoint;

    emit SetMultiplier(_pid, oldAllocPoint, _newAllocPoint);
  }

  // View function to see pending CAKEs on frontend.
  function pendingReward(uint256 _pid, address _user)
    external
    view
    returns (uint256, uint256)
  {
    PoolInfo storage pool = pools[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    uint256 accStakingPerShare = pool.accStakingRewardPerShare;
    uint256 lpSupply = pool.totalLongSupply + pool.totalShortSupply;
    if (lpSupply != 0 && block.number > pool.lastStakingRewardBlock) {
      uint256 multiplier = getMultiplier(pool.lastStakingRewardBlock);
      if (multiplier > 0) {
        uint256 dptReward = (multiplier * dptPerBlock * pool.allocPoint) /
          totalAllocPoint;
        accStakingPerShare += (dptReward * PRECISION) / lpSupply;
      }
    }

    return (
      ((user.longAmount + user.shortAmount) * accStakingPerShare) /
        PRECISION -
        user.rewardStakingDebt +
        userDptReward[_user],
      (pool.cakePerLong *
        user.longAmount +
        pool.cakePerShort *
        user.shortAmount) /
        PRECISION -
        user.cakeDebt
    );
  }

  function pendingAllReward(address _user)
    external
    view
    returns (uint256 pendingDpt, uint256 pendingCake)
  {
    uint256 length = pools.length;
    for (uint256 i = 0; i < length; i++) {
      PoolInfo storage pool = pools[i];
      UserInfo storage user = userInfo[i][_user];
      uint256 accStakingPerShare = pool.accStakingRewardPerShare;
      uint256 lpSupply = pool.totalLongSupply + pool.totalShortSupply;
      if (lpSupply != 0 && block.number > pool.lastStakingRewardBlock) {
        uint256 multiplier = getMultiplier(pool.lastStakingRewardBlock);
        if (multiplier > 0) {
          uint256 dptReward = (multiplier * dptPerBlock * pool.allocPoint) /
            totalAllocPoint;
          accStakingPerShare += (dptReward * PRECISION) / lpSupply;
        }
      }

      pendingDpt +=
        ((user.longAmount + user.shortAmount) * accStakingPerShare) /
        PRECISION -
        user.rewardStakingDebt;

      pendingCake +=
        (pool.cakePerLong *
          user.longAmount +
          pool.cakePerShort *
          user.shortAmount) /
        PRECISION -
        user.cakeDebt;
    }

    pendingDpt += userDptReward[_user];
  }

  function claimAllReward() external nonReentrant {
    uint256 length = pools.length;

    for (uint256 i = 0; i < length; i++) {
      UserInfo memory user = userInfo[i][msg.sender];

      if (status.isLocking) {
        updatePool(i);
      }

      claimCake(i, msg.sender, user.longAmount, user.shortAmount);

      claimDpt(i, msg.sender, user.longAmount, user.shortAmount);
    }
  }

  function setPoolCanYieldCake(uint256 _pid, uint256 _poolIdPancake)
    external
    onlyOwner
  {
    require(!status.isLocking, "should not do this when locking");
    PoolInfo storage pool = pools[_pid];
    require(pool.canYieldCake == 0, "can yield cake already");

    pool.canYieldCake = 1;
    pool.poolIdPancake = _poolIdPancake;

    uint256 currentAllowance = pool.lpToken.allowance(
      address(this),
      address(masterchef)
    );

    pool.lpToken.safeIncreaseAllowance(
      address(masterchef),
      type(uint256).max - currentAllowance
    );
  }

  function deposit(
    uint256 poolId,
    uint256 longAmount,
    uint256 shortAmount
  ) external nonReentrant {
    require(status.isLocking == false, "locking");
    require(
      longAmount > 0 || shortAmount > 0,
      "PREDICTION: DEPOSIT ZERO BALANCE"
    );

    PoolInfo storage pool = pools[poolId];
    UserInfo storage user = userInfo[poolId][msg.sender];

    uint256 totalDepositAmount = longAmount + shortAmount;
    uint256 oldUserLongAmount = user.longAmount;
    uint256 oldUserShortAmount = user.shortAmount;
    uint256 newUserLongAmount = oldUserLongAmount + longAmount;
    uint256 newUserShortAmount = oldUserShortAmount + shortAmount;

    claimCake(poolId, msg.sender, newUserLongAmount, newUserShortAmount);

    claimDpt(poolId, msg.sender, newUserLongAmount, newUserShortAmount);

    user.shortAmount = newUserShortAmount;
    user.longAmount = newUserLongAmount;

    pool.totalLongSupply += longAmount;
    pool.totalShortSupply += shortAmount;

    pool.lpToken.safeTransferFrom(
      msg.sender,
      address(this),
      totalDepositAmount
    );

    emit Deposit(msg.sender, poolId, longAmount, shortAmount);
  }

  function claimCake(
    uint256 _pid,
    address _user,
    uint256 newLongAmount,
    uint256 newShortAmount
  ) private {
    PoolInfo storage pool = pools[_pid];
    UserInfo storage user = userInfo[_pid][_user];

    uint256 pendingCake = (user.longAmount *
      pool.cakePerLong +
      user.shortAmount *
      pool.cakePerShort) /
      PRECISION -
      user.cakeDebt;

    if (pendingCake > 0) {
      cake.safeTransfer(msg.sender, pendingCake);
    }

    user.cakeDebt =
      (newLongAmount * pool.cakePerLong + newShortAmount * pool.cakePerShort) /
      PRECISION;
  }

  function claimDpt(
    uint256 _pid,
    address _user,
    uint256 newLongAmount,
    uint256 newShortAmount
  ) private {
    PoolInfo storage pool = pools[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    uint256 pendingDpt = ((user.longAmount + user.shortAmount) *
      pool.accStakingRewardPerShare) /
      PRECISION -
      user.rewardStakingDebt;

    if (pendingDpt + userDptReward[msg.sender] > 0) {
      dpt.safeTransfer(msg.sender, pendingDpt + userDptReward[msg.sender]);
      userDptReward[msg.sender] = 0;
    }

    user.rewardStakingDebt =
      (pool.accStakingRewardPerShare * (newLongAmount + newShortAmount)) /
      PRECISION;
  }

  function withdraw(
    uint256 poolId,
    uint256 longAmount,
    uint256 shortAmount
  ) external nonReentrant {
    PoolInfo storage pool = pools[poolId];
    UserInfo storage user = userInfo[poolId][msg.sender];

    require(user.longAmount >= longAmount, "withdraw : not enough balance");
    require(user.shortAmount >= shortAmount, "withdraw : not enough balance");

    uint256 totalWithdrawAmount = longAmount + shortAmount;

    uint256 newUserLongAmount = user.longAmount - longAmount;
    uint256 newUserShortAmount = user.shortAmount - shortAmount;

    if (status.isLocking) {
      updatePool(poolId);
    }

    claimCake(poolId, msg.sender, newUserLongAmount, newUserShortAmount);

    claimDpt(poolId, msg.sender, newUserLongAmount, newUserShortAmount);

    user.shortAmount = newUserShortAmount;
    user.longAmount = newUserLongAmount;

    pool.totalLongSupply -= longAmount;
    pool.totalShortSupply -= shortAmount;

    uint256 fee;
    uint256 oldCake = cake.balanceOf(address(this));

    if (status.isLocking) {
      fee = (totalWithdrawAmount * withdrawFee) / 10000;

      if (pool.canYieldCake == 1) {
        if (poolId == 0) {
          masterchef.leaveStaking(totalWithdrawAmount);
        } else {
          masterchef.withdraw(pool.poolIdPancake, totalWithdrawAmount);
        }
      }
    }

    if (fee > 0) {
      pool.lpToken.safeTransfer(devAddress, fee);
    }

    pool.lpToken.safeTransfer(msg.sender, totalWithdrawAmount - fee);

    uint256 newCake = cake.balanceOf(address(this));

    cakeInterest += newCake - oldCake;

    emit Withdraw(msg.sender, poolId, longAmount, shortAmount);
  }

  function startLocking(uint256 _dptPerBlock) external onlyUpkeeper {
    require(!status.isLocking, "is already locking");
    require(
      block.timestamp > status.lastUpdatedAt + depositDuration,
      "should not lock"
    );

    status.isLocking = true;
    status.lastUpdatedAt = block.timestamp;

    dptPerBlock = _dptPerBlock;

    uint256 length = pools.length;
    for (uint256 i = 0; i < length; i++) {
      if (pools[i].canYieldCake == 1) {
        if (i == 0) {
          masterchef.enterStaking(
            pools[i].totalLongSupply + pools[i].totalShortSupply
          );
        } else {
          masterchef.deposit(
            pools[i].poolIdPancake,
            pools[i].totalLongSupply + pools[i].totalShortSupply
          );
        }
      }

      // Don't need to update pool because we don't generate dpt this time
      pools[i].lastStakingRewardBlock = block.number;
    }

    emit Lock(_dptPerBlock);
  }

  function endGame(
    address[] memory randomRewardUser,
    uint256 totalRewardRandomUsers
  ) external onlyUpkeeper {
    require(status.isLocking, "is already not locking");
    require(
      block.timestamp > status.lastUpdatedAt + lockDuration,
      "not right time to end game"
    );

    int256 initialPrice = status.initialPrice;
    int256 currentPrice = _getPrice();
    if (status.initialPrice < currentPrice) {
      status.isShortWinLastRound = false;
    } else {
      status.isShortWinLastRound = true;
    }

    // Use to calculate how much cake interest in 1 round
    uint256 oldCakeBalance = cake.balanceOf(address(this));

    uint256 length = pools.length;

    for (uint256 i = 0; i < length; i++) {
      // if pool can yield cake, withdraw from pancake
      if (pools[i].canYieldCake == 1) {
        uint256 pid = pools[i].poolIdPancake;
        if (i == 0) {
          masterchef.leaveStaking(
            masterchef.userInfo(pid, address(this)).amount
          );
        } else {
          masterchef.withdraw(
            pid,
            masterchef.userInfo(pid, address(this)).amount
          );
        }
      }

      // To get the lastest accumulated dpt per share each pool
      updatePool(i);
    }

    uint256 newCakeBalance = cake.balanceOf(address(this));

    // Minus cake from user
    uint256 totalCakeReward = newCakeBalance -
      oldCakeBalance -
      pools[0].totalLongSupply -
      pools[0].totalShortSupply +
      cakeInterest;

    for (uint256 i = 0; i < length; i++) {
      if (status.isShortWinLastRound) {
        if (pools[i].totalShortSupply > 0) {
          pools[i].cakePerShort +=
            (totalCakeReward * PRECISION * pools[i].allocPoint) /
            (pools[i].totalShortSupply * totalAllocPoint);
        }
      } else {
        if (pools[i].totalLongSupply > 0) {
          pools[i].cakePerLong +=
            (totalCakeReward * PRECISION * pools[i].allocPoint) /
            (pools[i].totalLongSupply * totalAllocPoint);
        }
      }
    }

    uint256 randomUsersLength = randomRewardUser.length;
    require(
      randomUsersLength <= dptRewardRate.length,
      "Random rewarded users too long"
    );
    for (uint256 i = 0; i < randomUsersLength; i++) {
      userDptReward[randomRewardUser[i]] +=
        (totalRewardRandomUsers * dptRewardRate[i]) /
        100;
    }

    status.isLocking = false;
    status.lastUpdatedAt = block.timestamp;
    status.initialPrice = currentPrice;
    
    cakeInterest = 0;

    emit EndGame(
      status.isShortWinLastRound,
      totalCakeReward,
      currentPrice,
      randomRewardUser,
      initialPrice
    );
  }

  /**
   * @dev chainlink keeper checkUpkeep function to constantly check whether we need function call
   **/
  function checkUpkeep() external view returns (uint256) {
    if (!status.isStartedFirstRound) {
      return 0;
    }
    if (
      status.isLocking == false &&
      block.timestamp > status.lastUpdatedAt + depositDuration
    ) {
      return 1;
    } else if (
      status.isLocking == true &&
      block.timestamp > status.lastUpdatedAt + lockDuration
    ) {
      return 2;
    }
    return 0;
  }

  function emergencyWithdraw() external onlyOwner {
    address owner = owner();
    uint256 length = pools.length;

    for (uint256 i = 0; i < length; i++) {
      PoolInfo storage pool = pools[i];
      if (status.isLocking) {
        if (pool.canYieldCake == 1) {
          if (i == 0) {
            masterchef.leaveStaking(
              masterchef.userInfo(pool.poolIdPancake, address(this)).amount
            );
          } else {
            masterchef.withdraw(
              pool.poolIdPancake,
              masterchef.userInfo(pool.poolIdPancake, address(this)).amount
            );
          }
        }
      }

      pool.lpToken.safeTransfer(owner, pool.lpToken.balanceOf(address(this)));
    }
  }
}
