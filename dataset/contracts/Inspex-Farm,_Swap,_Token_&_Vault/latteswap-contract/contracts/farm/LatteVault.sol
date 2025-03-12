// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./interfaces/IMasterBarista.sol";

contract LatteVault is OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, AccessControlUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using SafeMathUpgradeable for uint256;

  bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

  struct UserInfo {
    uint256 amount; // number of user staking amount
    uint256 shares; // number of shares for a user
    uint256 lastDepositedTime; // keeps track of deposited time for potential penalty
    uint256 latteAtLastUserAction; // keeps track of LATTE deposited at the last user action
    uint256 lastUserActionTime; // keeps track of the last user action time
  }

  IERC20Upgradeable public latte; // LATTEv2 token
  IERC20Upgradeable public bean; // BEANv2 token

  IMasterBarista public masterBarista;

  mapping(address => UserInfo) public userInfo;

  uint256 public totalShares;
  uint256 public totalStakingAmount;
  uint256 public lastHarvestedTime;
  address public treasury;
  mapping(address => bool) public okFarmers;

  uint256 public constant MAX_PERFORMANCE_FEE = 500; // 5%
  uint256 public constant MAX_CALL_FEE = 100; // 1%
  uint256 public constant MAX_WITHDRAW_FEE = 100; // 1%
  uint256 public constant MAX_WITHDRAW_FEE_PERIOD = 72 hours; // 3 days

  uint256 public performanceFee;
  uint256 public withdrawFee;
  uint256 public withdrawFeePeriod;

  event Deposit(address indexed sender, uint256 amount, uint256 shares, uint256 lastDepositedTime);
  event Withdraw(address indexed sender, uint256 amount, uint256 shares);
  event TransferPerformanceFee(address indexed sender, uint256 performanceFee);
  event Harvest(address indexed sender, uint256 balance);
  event LogSetTreasury(address indexed prevTreasury, address indexed newTreasury);
  event LogSetPerformanceFee(uint256 prevPerformanceFee, uint256 newPerformanceFee);
  event LogSetWithdrawFee(uint256 prevWithdrawFee, uint256 newWithdrawFee);
  event LogSetWithdrawFeePeriod(uint256 prevWithdrawFeePeriod, uint256 newWithdrawFeePeriod);
  event LogEmergencyWithdraw(uint256 withdrawAmount);
  event LogInCaseTokensGetStuck(address indexed token, uint256 amount);
  event Pause();
  event Unpause();

  /**
   * @notice Upgradeable Initializer Function
   * @param _latte: LATTEv2 token contract
   * @param _bean: BeanBagv2 token contract
   * @param _masterBarista: MasterBarista contract
   * @param _treasury: address of the treasury (collects fees)
   * @param _farmers: list of reinvestors
   */
  function initialize(
    IERC20Upgradeable _latte,
    IERC20Upgradeable _bean,
    IMasterBarista _masterBarista,
    address _treasury,
    address[] memory _farmers
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    PausableUpgradeable.__Pausable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
    AccessControlUpgradeable.__AccessControl_init();

    latte = _latte;
    masterBarista = _masterBarista;
    treasury = _treasury;
    bean = _bean;

    performanceFee = 200; // 2.00%
    withdrawFee = 10; // 0.1%
    withdrawFeePeriod = 72 hours; // 3 days

    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(GOVERNANCE_ROLE, _msgSender());

    uint256 len = _farmers.length;
    for (uint256 idx = 0; idx < len; idx++) {
      okFarmers[_farmers[idx]] = true;
    }
  }

  modifier onlyGovernance() {
    require(hasRole(GOVERNANCE_ROLE, _msgSender()), "LatteVault::onlyGovernance::only GOVERNANCE role");
    _;
  }

  /**
   * @notice Checks if the msg.sender is a ok farmer
   */
  modifier onlyFarmer() {
    require(okFarmers[msg.sender], "LatteVault::onlyFarmer::msg.sender is not farmer");
    _;
  }

  /// @dev Require that the caller must be an EOA account to avoid flash loans.
  modifier onlyEOA() {
    require(msg.sender == tx.origin, "LatteVault::onlyEOA:: not eoa");
    _;
  }

  /**
   * @notice Deposits funds into the Latte Vault
   * @dev Only possible when contract not paused.
   * @param _amount: number of tokens to deposit (in LATTE)
   */
  function deposit(uint256 _amount) external whenNotPaused nonReentrant onlyEOA {
    require(_amount > 0, "LatteVault::deposit::nothing to deposit");

    _harvest();

    uint256 pool = balanceOf();

    latte.safeTransferFrom(msg.sender, address(this), _amount);

    uint256 currentShares = 0;
    if (totalShares != 0) {
      currentShares = (_amount.mul(totalShares)).div(pool);
    } else {
      currentShares = _amount;
    }
    UserInfo storage user = userInfo[msg.sender];

    user.shares = user.shares.add(currentShares);
    user.amount = user.amount.add(_amount);
    user.lastDepositedTime = block.timestamp;

    totalShares = totalShares.add(currentShares);
    totalStakingAmount = totalStakingAmount.add(_amount);

    user.latteAtLastUserAction = user.shares.mul(balanceOf()).div(totalShares);
    user.lastUserActionTime = block.timestamp;

    _earn();

    require(totalShares > 1e17, "LatteVault::deposit::no tiny shares");

    bean.safeTransfer(_msgSender(), _amount);

    emit Deposit(msg.sender, _amount, currentShares, block.timestamp);
  }

  /**
   * @notice Withdraws all funds for a user
   */
  function withdrawAll() external onlyEOA {
    withdraw(userInfo[msg.sender].shares);
  }

  /**
   * @notice Reinvests LATTE into MasterBarista
   * @dev Only possible when contract not paused.
   */
  function harvest() external onlyFarmer whenNotPaused nonReentrant {
    _harvest();
  }

  /// @dev internal function for harvest to be reusable within the contract
  function _harvest() internal {
    (uint256 userStakeAmount, , , ) = masterBarista.userInfo(address(latte), address(this));
    if (userStakeAmount == 0) {
      emit Harvest(msg.sender, 0);
      emit TransferPerformanceFee(msg.sender, 0);
      return;
    }
    IMasterBarista(masterBarista).harvest(address(this), address(latte));

    uint256 bal = available();
    uint256 currentPerformanceFee = bal.mul(performanceFee).div(10000);
    latte.safeTransfer(treasury, currentPerformanceFee);

    _earn();

    lastHarvestedTime = block.timestamp;

    emit Harvest(msg.sender, bal.sub(currentPerformanceFee));
    emit TransferPerformanceFee(msg.sender, currentPerformanceFee);
  }

  /**
   * @notice Sets treasury address
   * @dev Only callable by the contract owner.
   */
  function setTreasury(address _treasury) external onlyOwner {
    require(_treasury != address(0), "LatteVault::setTreasury::cannot be zero address");

    emit LogSetTreasury(treasury, _treasury);

    treasury = _treasury;
  }

  /**
   * @notice Sets performance fee
   * @dev Only callable by the contract admin.
   */
  function setPerformanceFee(uint256 _performanceFee) external onlyOwner {
    require(
      _performanceFee <= MAX_PERFORMANCE_FEE,
      "LatteVault::setPerformanceFee::performanceFee cannot be more than MAX_PERFORMANCE_FEE"
    );
    emit LogSetPerformanceFee(performanceFee, _performanceFee);
    performanceFee = _performanceFee;
  }

  /**
   * @notice Sets withdraw fee
   * @dev Only callable by the contract admin.
   */
  function setWithdrawFee(uint256 _withdrawFee) external onlyOwner {
    require(
      _withdrawFee <= MAX_WITHDRAW_FEE,
      "LatteVault::setWithdrawFee::withdrawFee cannot be more than MAX_WITHDRAW_FEE"
    );

    emit LogSetWithdrawFee(withdrawFee, _withdrawFee);

    withdrawFee = _withdrawFee;
  }

  /**
   * @notice Sets withdraw fee period
   * @dev Only callable by the contract admin.
   */
  function setWithdrawFeePeriod(uint256 _withdrawFeePeriod) external onlyOwner {
    require(
      _withdrawFeePeriod <= MAX_WITHDRAW_FEE_PERIOD,
      "LatteVault::setWithdrawFeePeriod::withdrawFeePeriod cannot be more than MAX_WITHDRAW_FEE_PERIOD"
    );

    emit LogSetWithdrawFeePeriod(withdrawFeePeriod, _withdrawFeePeriod);

    withdrawFeePeriod = _withdrawFeePeriod;
  }

  /**
   * @notice Withdraws from MasterChef to Vault without caring about rewards.
   * @dev EMERGENCY ONLY. Only callable by the contract admin.
   */
  function emergencyWithdraw() external onlyOwner {
    IMasterBarista(masterBarista).emergencyWithdraw(address(this), address(latte));
    uint256 bal = available();
    emit LogEmergencyWithdraw(bal);
  }

  /**
   * @notice Withdraw unexpected tokens sent to the Latte Vault
   */
  function inCaseTokensGetStuck(address _token) external onlyOwner {
    require(_token != address(latte), "LatteVault::inCaseTokensGetStuck::token cannot be same as deposit token");

    uint256 amount = IERC20Upgradeable(_token).balanceOf(address(this));
    IERC20Upgradeable(_token).safeTransfer(msg.sender, amount);

    emit LogInCaseTokensGetStuck(_token, amount);
  }

  /**
   * @notice Triggers stopped state
   * @dev Only possible when contract not paused.
   */
  function pause() external onlyGovernance whenNotPaused {
    _pause();
    emit Pause();
  }

  /**
   * @notice Returns to normal state
   * @dev Only possible when contract is paused.
   */
  function unpause() external onlyGovernance whenPaused {
    _unpause();
    emit Unpause();
  }

  /**
   * @notice Calculates the total pending rewards that can be restaked
   * @return Returns total pending LATTE rewards
   */
  function calculateTotalPendingLatteRewards() external view returns (uint256) {
    uint256 amount = IMasterBarista(masterBarista).pendingLatte(address(latte), address(this));
    amount = amount.add(available());

    return amount;
  }

  /**
   * @notice Calculates the price per share
   */
  function getPricePerFullShare() external view returns (uint256) {
    return totalShares == 0 ? 1e18 : balanceOf().mul(1e18).div(totalShares);
  }

  /**
   * @notice Withdraws from funds from the Latte Vault
   * @param _shares: Number of shares to withdraw
   */
  function withdraw(uint256 _shares) public nonReentrant onlyEOA {
    UserInfo storage user = userInfo[msg.sender];
    require(_shares > 0, "LatteVault::withdraw::nothing to withdraw");
    require(_shares <= user.shares, "LatteVault::withdraw::withdraw amount exceeds balance");

    _harvest();

    uint256 _beanAmount = (user.amount.mul(_shares)).div(user.shares);
    user.amount = user.amount.sub(_beanAmount);
    totalStakingAmount = totalStakingAmount.sub(_beanAmount);

    bean.safeTransferFrom(_msgSender(), address(this), _beanAmount);

    uint256 currentAmount = (balanceOf().mul(_shares)).div(totalShares);
    user.shares = user.shares.sub(_shares);
    totalShares = totalShares.sub(_shares);

    uint256 bal = available();
    if (bal < currentAmount) {
      uint256 balWithdraw = currentAmount.sub(bal);
      IMasterBarista(masterBarista).withdrawLatteV2(address(this), balWithdraw);
      uint256 balAfter = available();
      uint256 diff = balAfter.sub(bal);
      if (diff < balWithdraw) {
        currentAmount = bal.add(diff);
      }
    }
    if (block.timestamp < user.lastDepositedTime.add(withdrawFeePeriod)) {
      uint256 currentWithdrawFee = currentAmount.mul(withdrawFee).div(10000);
      latte.safeTransfer(treasury, currentWithdrawFee);
      currentAmount = currentAmount.sub(currentWithdrawFee);
    }

    /// @notice optimistically transfer LATTE before update latteAtLastUserAction
    latte.safeTransfer(msg.sender, currentAmount);

    if (user.shares > 0) {
      user.latteAtLastUserAction = user.shares.mul(balanceOf()).div(totalShares);
    } else {
      user.latteAtLastUserAction = 0;
    }

    user.lastUserActionTime = block.timestamp;

    require(totalShares > 1e17, "LatteVault::deposit::no tiny shares");

    emit Withdraw(msg.sender, currentAmount, _shares);
  }

  /**
   * @notice Custom logic for how much the vault allows to be borrowed
   * @dev The contract puts 100% of the tokens to work.
   */
  function available() public view returns (uint256) {
    return latte.balanceOf(address(this));
  }

  /**
   * @notice Calculates the total underlying tokens
   * @dev It includes tokens held by the contract and held in MasterBarista
   */
  function balanceOf() public view returns (uint256) {
    (uint256 amount, , , ) = IMasterBarista(masterBarista).userInfo(address(latte), address(this));
    return latte.balanceOf(address(this)).add(amount);
  }

  /**
   * @notice Deposits tokens into MasterBarista to earn staking rewards
   */
  function _earn() internal {
    uint256 bal = available();
    if (bal > 0) {
      latte.safeApprove(address(masterBarista), bal);
      IMasterBarista(masterBarista).depositLatteV2(address(this), bal);
      latte.safeApprove(address(masterBarista), 0);
    }
  }
}
