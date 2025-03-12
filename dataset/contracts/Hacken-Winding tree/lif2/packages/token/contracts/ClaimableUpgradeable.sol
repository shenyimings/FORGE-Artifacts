// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

abstract contract ClaimableUpgradeable is
  Initializable,
  ERC20Upgradeable,
  ReentrancyGuardUpgradeable
{
  // Original Lif token instance
  IERC20Upgradeable private _originalLif;

  // Feature stopped state
  bool private _stopped;

  // Mapping of a holder address to its balance in stuck
  mapping(address => uint256) internal _stuckBalance;

  /**
   * @dev Emitted when the stop is triggered by `account`.
   */
  event Stopped(address account);

  /**
   * @dev Emitted when the start is triggered by `account`.
   */
  event Started(address account);

  /**
   * @dev Emitted when `value` tokens are been claimed by the `holder`
   */
  event Claim(address indexed holder, uint256 value);

  /**
   * @dev Emitted when `value` tokens are been resurrected for the `holder`
   */
  event Resurrect(address indexed holder, uint256 value);

  /**
   * @dev Modifier to make a function callable only when the contract is not stopped.
   *
   * Requirements:
   *
   * - The contract must not be stopped.
   */
  modifier whenNotStopped() {
    require(!stopped(), "Claimable: stopped");
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is stopped.
   *
   * Requirements:
   *
   * - The contract must be stopped.
   */
  modifier whenStopped() {
    require(stopped(), "Claimable: started");
    _;
  }

  /**
   * @dev Sets the original Lif token instance
   *
   * Requirements:
   *
   * - `tokenAddress_` cannot be zero
   */
  // solhint-disable-next-line func-name-mixedcase
  function __Claimable_init(address tokenAddress_)
    internal
    initializer
  {
    require(tokenAddress_ != address(0), "Claimable: invalid token address");
    _stopped = false;
    _originalLif = IERC20Upgradeable(tokenAddress_);
    __ReentrancyGuard_init();

    // Mint the initial supply.
    // These tokens will be held by the contract balance
    // until be claimed by original Lif token holders
    _mint(address(this), _originalLif.totalSupply());

    // Extra initialization actions
    _afterClaimableInitHook();
  }

  /**
   * @dev Returns the original Lif token address
   */
  function originalLif() external view virtual returns (address) {
    return address(_originalLif);
  }

  function _mint(address to, uint256 amount)
    internal
    virtual
    override(ERC20Upgradeable)
  {
    super._mint(to, amount);
  }

  /**
   * @dev Claims tokens by original lif token holder
   *
   * Requirements:
   *
   * - The original Lif token balance of the holder must be positive
   * - Original tokens must be allowed to transfer
   * - a function call must not be reentrant call
   */
  function claim() external virtual nonReentrant {
    address holder = _msgSender();
    uint256 balance = _originalLif.balanceOf(holder);

    require(balance > 0, "Claimable: nothing to claim");

    // Fetches all the old tokens...
    SafeERC20Upgradeable.safeTransferFrom(
      _originalLif,
      holder,
      address(this),
      balance
    );
    require(
      _originalLif.balanceOf(holder) == 0,
      "Claimable: unable to transfer"
    );

    // ...and sends new tokens in change
    _transfer(address(this), holder, balance);
    emit Claim(holder, balance);

    // Resurrect tokens if exists
    uint256 holderStuckBalance = _stuckBalance[holder];
    if (holderStuckBalance > 0) {
      _stuckBalance[holder] = 0;
      _transfer(address(this), holder, holderStuckBalance);
      emit Resurrect(holder, holderStuckBalance);
    }
  }

  /**
    * @dev Returns true if the contract is stopped, and false otherwise.
    */
  function stopped() public view virtual returns (bool) {
    return _stopped;
  }

  /**
   * @dev Triggers stopped state.
   *
   * Requirements:
   *
   * - The contract must not be stopped.
   */
  function _stop() internal virtual whenNotStopped {
    _stopped = true;
    emit Stopped(_msgSender());
  }

  /**
   * @dev Triggers started state.
   *
   * Requirements:
   *
   * - The contract must not be stopped.
   */
  function _start() internal virtual whenStopped {
    _stopped = false;
    emit Started(_msgSender());
  }

  /**
   * @dev Extra initializations hook.
   */
  function _afterClaimableInitHook() internal virtual initializer {}

  uint256[49] private __gap;
}
