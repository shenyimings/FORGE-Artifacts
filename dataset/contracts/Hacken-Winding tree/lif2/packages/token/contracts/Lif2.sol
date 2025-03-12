// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "./ClaimableUpgradeable.sol";

/**
 * @dev Lif ERC20 token
 */
contract Lif2 is
  Initializable,
  ERC20Upgradeable,
  PausableUpgradeable,
  OwnableUpgradeable,
  ERC20PermitUpgradeable,
  ClaimableUpgradeable
{
  /**
   * @dev Initializes the contract
   *
   * Note: Must be called as soon as possible after the contract deployment
   */
  function initialize(address tokenAddress_) external initializer {
    __ERC20_init("LifToken", "LIF");
    __Pausable_init();
    __Ownable_init();
    __ERC20Permit_init("LifToken");
    __Claimable_init(tokenAddress_);
  }

  /**
   * @dev Initializes the _stuckBalance storage.
   */
  function _afterClaimableInitHook()
    internal
    override(ClaimableUpgradeable)
    virtual
    initializer
  {
    // Initialize the `_stuckBalance`, which contains tokens that have been stuck in the old contract
    // Created on the base of https://etherscan.io/token/0xeb9951021698b42e4399f9cbb6267aa35f82d59d?a=0xeb9951021698b42e4399f9cbb6267aa35f82d59d
    _stuckBalance[0x9067Ae747976631D6194311f6Cf6fD83A561b0C9] += 9830000000000000000000;
    _stuckBalance[0x415dF4Ef8f2E4afAEBd99eC1d49b05A220aC3673] += 51999999999999999995385;
    _stuckBalance[0x77E4588685744cdbDdBf677860B42A3c28E166DD] += 751039901550000000000;
    _stuckBalance[0xb91e2071762E2825D3ec7513304b7f833Be32d48] += 10000;
    _stuckBalance[0x72bA03F175420890d18423500f0C6b1f2B3e821D] += 5045000000000000000000;
    _stuckBalance[0x692306857D17a8f31bB5fEb17cfE765773487E66] += 185963000000000000000;
    _stuckBalance[0xA7F660812022155adA962F54D2C289C5592F518A] += 500000000000000000000;
    _stuckBalance[0x8adbf5f4F80319CFBe8d49976aAD9Aacc158B4b8] += 3050000000000000000000;
    _stuckBalance[0x77E4588685744cdbDdBf677860B42A3c28E166DD] += 40000000000000000000;
    _stuckBalance[0x77928bbE911befe4bD4E5D6A6C6D1b7ca58eAB6E] += 300000000000000000000;
  }

  /**
   * @dev Triggers paused state.
   */
  function pause() external onlyOwner {
    _pause();
  }

  /**
   * @dev Returns to normal paused state.
   */
  function unpause() external onlyOwner {
    _unpause();
  }

  /**
   * @dev Triggers stopped state.
   */
  function stop() external onlyOwner {
    _stop();
  }

  /**
   * @dev Triggers started state.
   */
  function start() external onlyOwner {
    _start();
  }

  /**
   * @dev See {ERC20Upgradeable-_beforeTokenTransfer}
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override whenNotPaused {
    super._beforeTokenTransfer(from, to, amount);
  }

  // The following functions are overrides required by Solidity.

  /**
   * @dev See {ERC20Upgradeable-_afterTokenTransfer}
   */
  function _afterTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override(ERC20Upgradeable) {
    super._afterTokenTransfer(from, to, amount);
  }

  /**
   * @dev See {ERC20Upgradeable-_mint}
   */
  function _mint(address to, uint256 amount)
    internal
    override(ERC20Upgradeable, ClaimableUpgradeable)
  {
    super._mint(to, amount);
  }

  /**
   * @dev See {ERC20Upgradeable-_burn}
   */
  function _burn(address account, uint256 amount)
    internal
    override(ERC20Upgradeable)
  {
    super._burn(account, amount);
  }

  /**
   * @dev See {IERC20-transfer}.
   *
   * Requirements:
   *
   * - `recipient` cannot be the zero address.
   * - `recipient` cannot be a contract
   * - the caller must have a balance of at least `amount`.
   */
  function transfer(address recipient, uint256 amount)
    public
    virtual
    override
    returns (bool)
  {
    require(
      !AddressUpgradeable.isContract(recipient),
      "ERC20: transfer to the contract"
    );
    return super.transfer(recipient, amount);
  }
}
