// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/IMasterBarista.sol";

contract LatteVault is Ownable, Pausable, ReentrancyGuard, AccessControl {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
  // keccak256(abi.encodePacked("I am an EOA"))
  bytes32 public constant SIGNATURE_HASH = 0x08367bb0e0d2abf304a79452b2b95f4dc75fda0fc6df55dca6e5ad183de10cf0;

  struct UserInfo {
    uint256 shares; // number of shares for a user
    uint256 lastDepositedTime; // keeps track of deposited time for potential penalty
    uint256 latteAtLastUserAction; // keeps track of LATTE deposited at the last user action
    uint256 lastUserActionTime; // keeps track of the last user action time
  }

  IERC20 public immutable latte; // LATTE token

  IMasterBarista public immutable masterBarista;

  mapping(address => UserInfo) public userInfo;

  uint256 public totalShares;
  uint256 public lastHarvestedTime;
  address public treasury;
  mapping(address => bool) public okFarmers;

  uint256 public constant MAX_PERFORMANCE_FEE = 500; // 5%
  uint256 public constant MAX_CALL_FEE = 100; // 1%
  uint256 public constant MAX_WITHDRAW_FEE = 100; // 1%
  uint256 public constant MAX_WITHDRAW_FEE_PERIOD = 72 hours; // 3 days

  uint256 public performanceFee = 225; // 2.25%
  uint256 public withdrawFee = 10; // 0.1%
  uint256 public withdrawFeePeriod = 72 hours; // 3 days

  event Deposit(address indexed sender, uint256 amount, uint256 shares, uint256 lastDepositedTime);
  event Withdraw(address indexed sender, uint256 amount, uint256 shares);
  event Harvest(address indexed sender, uint256 performanceFee);
  event Pause();
  event Unpause();

  /**
   * @notice Constructor
   * @param _latte: LATTE token contract
   * @param _masterBarista: MasterBarista contract
   * @param _treasury: address of the treasury (collects fees)
   */
  constructor(
    IERC20 _latte,
    IMasterBarista _masterBarista,
    address _treasury,
    address[] memory _farmers
  ) public {
    latte = _latte;
    masterBarista = _masterBarista;
    treasury = _treasury;

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

  modifier permit(bytes calldata _sig) {
    address recoveredAddress = ECDSA.recover(ECDSA.toEthSignedMessageHash(SIGNATURE_HASH), _sig);
    require(recoveredAddress == _msgSender(), "LatteVault::permit::INVALID_SIGNATURE");
    _;
  }

  /**
   * @notice Deposits funds into the Latte Vault
   * @dev Only possible when contract not paused.
   * @param _amount: number of tokens to deposit (in LATTE)
   */
  function deposit(uint256 _amount, bytes calldata _sig) external whenNotPaused nonReentrant permit(_sig) {
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
    user.lastDepositedTime = block.timestamp;

    totalShares = totalShares.add(currentShares);

    user.latteAtLastUserAction = user.shares.mul(balanceOf()).div(totalShares);
    user.lastUserActionTime = block.timestamp;

    _earn();

    require(totalShares > 1e17, "LatteVault::deposit::no tiny shares");

    emit Deposit(msg.sender, _amount, currentShares, block.timestamp);
  }

  /**
   * @notice Withdraws all funds for a user
   */
  function withdrawAll(bytes calldata _sig) external permit(_sig) {
    withdraw(userInfo[msg.sender].shares, _sig);
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
    IMasterBarista(masterBarista).harvest(address(this), address(latte));

    uint256 bal = available();
    uint256 currentPerformanceFee = bal.mul(performanceFee).div(10000);
    latte.safeTransfer(treasury, currentPerformanceFee);

    _earn();

    lastHarvestedTime = block.timestamp;

    emit Harvest(msg.sender, currentPerformanceFee);
  }

  /**
   * @notice Sets treasury address
   * @dev Only callable by the contract owner.
   */
  function setTreasury(address _treasury) external onlyOwner {
    require(_treasury != address(0), "LatteVault::setTreasury::cannot be zero address");
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
    withdrawFeePeriod = _withdrawFeePeriod;
  }

  /**
   * @notice Withdraws from MasterChef to Vault without caring about rewards.
   * @dev EMERGENCY ONLY. Only callable by the contract admin.
   */
  function emergencyWithdraw() external onlyOwner {
    IMasterBarista(masterBarista).emergencyWithdraw(address(this), address(latte));
  }

  /**
   * @notice Withdraw unexpected tokens sent to the Latte Vault
   */
  function inCaseTokensGetStuck(address _token) external onlyOwner {
    require(_token != address(latte), "LatteVault::inCaseTokensGetStuck::token cannot be same as deposit token");

    uint256 amount = IERC20(_token).balanceOf(address(this));
    IERC20(_token).safeTransfer(msg.sender, amount);
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
  function withdraw(uint256 _shares, bytes calldata _sig) public nonReentrant permit(_sig) {
    UserInfo storage user = userInfo[msg.sender];
    require(_shares > 0, "LatteVault::withdraw::nothing to withdraw");
    require(_shares <= user.shares, "LatteVault::withdraw::withdraw amount exceeds balance");

    uint256 currentAmount = (balanceOf().mul(_shares)).div(totalShares);
    user.shares = user.shares.sub(_shares);
    totalShares = totalShares.sub(_shares);

    uint256 bal = available();
    if (bal < currentAmount) {
      uint256 balWithdraw = currentAmount.sub(bal);
      IMasterBarista(masterBarista).withdraw(address(this), address(latte), balWithdraw);
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
      IMasterBarista(masterBarista).deposit(address(this), address(latte), bal);
    }
  }
}
