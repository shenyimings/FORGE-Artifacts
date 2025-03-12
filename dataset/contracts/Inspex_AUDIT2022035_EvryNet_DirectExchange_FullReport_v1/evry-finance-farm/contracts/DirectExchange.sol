//contracts/DirectExchange.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract DirectExchange is ReentrancyGuardUpgradeable, OwnableUpgradeable, PausableUpgradeable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  uint256 private constant RATIO_PRECISION = 1e18;

  IERC20 public tokenIn;
  IERC20 public tokenOut;
  uint256 public tokenRatio;

  address public operator;
  address public treasury;

  uint256 public totalExchangeAmount;

  event Exchange(address indexed user, uint256 tokenInAmount, uint256 tokenOutAmount);
  event NewOperatorAddress(address indexed operator);
  event NewTreasuryAddress(address indexed treasury);
  event ClaimTreasury(address indexed treasury, uint256 tokenInAmount);
  event WithdrawTreasury(address indexed treasury, uint256 tokenOutAmount);

  modifier onlyOperator() {
    require(msg.sender == operator, "DirectExchange: not operator");
    _;
  }

  modifier onlyTreasury() {
    require(msg.sender == treasury, "DirectExchange: not treasury");
    _;
  }

  function initialize(
    IERC20 _tokenIn,
    IERC20 _tokenOut,
    uint256 _tokenRatio,
    address _operator,
    address _treasury,
    address _admin
  ) public initializer {
    __Ownable_init();
    __ReentrancyGuard_init();

    tokenIn = _tokenIn;
    tokenOut = _tokenOut;
    tokenRatio = _tokenRatio;
    operator = _operator;
    treasury = _treasury;

    transferOwnership(_admin);
  }

  /**
   * @notice Exchange tokenIn to tokenOut with fixed ratio
   */
  function exchange(uint256 _amount) external whenNotPaused nonReentrant {
    uint256 tokenOutBalance = tokenOut.balanceOf(address(this));
    require(tokenOutBalance > 0, "DirectExchange: insufficient token reserve");

    uint256 tokenInAmount = _amount;
    uint256 tokenOutAmount = _amount.mul(tokenRatio).div(RATIO_PRECISION);

    if (tokenOutAmount > tokenOutBalance) {
      tokenInAmount = tokenOutBalance.mul(RATIO_PRECISION).div(tokenRatio);
      tokenOutAmount = tokenOutBalance; 
    }

    uint256 preBalance = tokenIn.balanceOf(address(this));
    tokenIn.safeTransferFrom(msg.sender, address(this), tokenInAmount);
    uint256 postBalance = tokenIn.balanceOf(address(this));

    require(postBalance.sub(preBalance) == tokenInAmount, "DirectExchange: not support deflationary token");

    totalExchangeAmount = totalExchangeAmount.add(tokenOutAmount);
    tokenOut.safeTransfer(msg.sender, tokenOutAmount);

    emit Exchange(msg.sender, tokenInAmount, tokenOutAmount);
  }

  /**
   * @notice Claim tokenIn from contract
   * @dev Callable by treasury
   */
  function claimTreasury() external onlyTreasury {
    uint256 amount = tokenIn.balanceOf(address(this));
    tokenIn.safeTransfer(treasury, amount);

    emit ClaimTreasury(treasury, amount);
  }

  /**
   * @notice Withdraw tokenOut from contract
   * @dev Callable by treasury
   */
  function withdrawTreasury(uint256 _amount) external whenPaused onlyTreasury {
    tokenOut.safeTransfer(treasury, _amount);

    emit WithdrawTreasury(treasury, _amount);
  }

  /**
   * @notice called by the operator to pause, triggers stopped state
   */
  function pause() external whenNotPaused onlyOperator {
    _pause();
  }

  /**
   * @notice called by the operator to unpause, returns to normal state
   */
  function unpause() external whenPaused onlyOperator {
    _unpause();
  }

  function isPaused() public view returns (bool) {
    return paused();
  }

  /**
   * @notice Set operator address
   * @dev Callable by owner
   */
  function setOperator(address _operator) external onlyOwner {
    require(_operator != address(0), "DirectExchange: cannot be zero address");
    operator = _operator;

    emit NewOperatorAddress(_operator);
  }

  /**
   * @notice Set treasury address
   * @dev Callable by owner
   */
  function setTreasury(address _treasury) external onlyOwner {
    require(_treasury != address(0), "DirectExchange: cannot be zero address");
    treasury = _treasury;

    emit NewTreasuryAddress(_treasury);
  }
}
