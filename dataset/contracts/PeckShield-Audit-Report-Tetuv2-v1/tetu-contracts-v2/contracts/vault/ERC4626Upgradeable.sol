// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../openzeppelin/ERC20PermitUpgradeable.sol";
import "../openzeppelin/SafeERC20.sol";
import "../openzeppelin/ReentrancyGuard.sol";
import "../interfaces/IERC4626.sol";
import "../lib/FixedPointMathLib.sol";

/// @notice Minimal ERC4626 tokenized Vault implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/mixins/ERC4626.sol)
/// @author belbix - adopted to proxy pattern + added ReentrancyGuard
abstract contract ERC4626Upgradeable is ERC20PermitUpgradeable, ReentrancyGuard, IERC4626 {
  using SafeERC20 for IERC20;
  using FixedPointMathLib for uint;

  /// @dev The address of the underlying token used for the Vault uses for accounting,
  ///      depositing, and withdrawing
  IERC20 internal _asset;

  function __ERC4626_init(
    IERC20 asset_,
    string memory _name,
    string memory _symbol
  ) internal onlyInitializing {
    __ERC20_init(_name, _symbol);
    _asset = asset_;
  }

  function decimals() public view override(IERC20Metadata, ERC20Upgradeable) returns (uint8) {
    return IERC20Metadata(address(_asset)).decimals();
  }

  function asset() external view override returns (address) {
    return address(_asset);
  }

  /*//////////////////////////////////////////////////////////////
  //             DEPOSIT/WITHDRAWAL LOGIC
  //////////////////////////////////////////////////////////////*/

  /// @dev Mints vault shares to receiver by depositing exactly amount of assets.
  function deposit(
    uint assets,
    address receiver
  ) public nonReentrant virtual override returns (uint shares) {
    require(assets <= maxDeposit(receiver), "MAX");

    shares = previewDeposit(assets);
    // Check for rounding error since we round down in previewDeposit.
    require(shares != 0, "ZERO_SHARES");

    // Need to transfer before minting or ERC777s could reenter.
    _asset.safeTransferFrom(msg.sender, address(this), assets);

    _mint(receiver, shares);

    emit Deposit(msg.sender, receiver, assets, shares);

    afterDeposit(assets, shares);
  }

  function mint(
    uint shares,
    address receiver
  ) public nonReentrant virtual override returns (uint assets) {
    require(shares <= maxMint(receiver), "MAX");

    assets = previewMint(shares);
    // No need to check for rounding error, previewMint rounds up.

    // Need to transfer before minting or ERC777s could reenter.
    _asset.safeTransferFrom(msg.sender, address(this), assets);

    _mint(receiver, shares);

    emit Deposit(msg.sender, receiver, assets, shares);

    afterDeposit(assets, shares);
  }

  function withdraw(
    uint assets,
    address receiver,
    address owner
  ) public nonReentrant virtual override returns (uint shares) {
    require(assets <= maxWithdraw(owner), "MAX");

    shares = previewWithdraw(assets);
    // No need to check for rounding error, previewWithdraw rounds up.

    if (msg.sender != owner) {
      uint allowed = _allowances[owner][msg.sender];
      // Saves gas for limited approvals.
      if (allowed != type(uint).max) _allowances[owner][msg.sender] = allowed - shares;
    }

    beforeWithdraw(assets, shares);

    _burn(owner, shares);

    emit Withdraw(msg.sender, receiver, owner, assets, shares);

    _asset.safeTransfer(receiver, assets);
  }

  /// @dev Redeems shares from owner and sends assets to receiver.
  function redeem(
    uint shares,
    address receiver,
    address owner
  ) public nonReentrant virtual override returns (uint assets) {
    require(shares <= maxRedeem(owner), "MAX");

    if (msg.sender != owner) {
      uint allowed = _allowances[owner][msg.sender];
      // Saves gas for limited approvals.
      if (allowed != type(uint).max) _allowances[owner][msg.sender] = allowed - shares;
    }

    assets = previewRedeem(shares);
    // Check for rounding error since we round down in previewRedeem.
    require(assets != 0, "ZERO_ASSETS");

    beforeWithdraw(assets, shares);

    _burn(owner, shares);

    emit Withdraw(msg.sender, receiver, owner, assets, shares);

    _asset.safeTransfer(receiver, assets);
  }

  /*//////////////////////////////////////////////////////////////
  //                  ACCOUNTING LOGIC
  //////////////////////////////////////////////////////////////*/

  /// @dev Total amount of the underlying asset that is “managed” by Vault
  function totalAssets() public view virtual override returns (uint);

  function convertToShares(uint assets) public view virtual override returns (uint) {
    uint supply = totalSupply();
    // Saves an extra SLOAD if totalSupply is non-zero.
    return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
  }

  function convertToAssets(uint shares) public view virtual override returns (uint) {
    uint supply = totalSupply();
    // Saves an extra SLOAD if totalSupply is non-zero.
    return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
  }

  function previewDeposit(uint assets) public view virtual override returns (uint) {
    return convertToShares(assets);
  }

  function previewMint(uint shares) public view virtual override returns (uint) {
    uint supply = totalSupply();
    // Saves an extra SLOAD if totalSupply is non-zero.
    return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
  }

  function previewWithdraw(uint assets) public view virtual override returns (uint) {
    uint supply = totalSupply();
    // Saves an extra SLOAD if totalSupply is non-zero.
    return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
  }

  function previewRedeem(uint shares) public view virtual override returns (uint) {
    return convertToAssets(shares);
  }

  ///////////////////////////////////////////////////////////////
  //           DEPOSIT/WITHDRAWAL LIMIT LOGIC
  ///////////////////////////////////////////////////////////////

  function maxDeposit(address) public view virtual override returns (uint) {
    return type(uint).max - 1;
  }

  function maxMint(address) public view virtual override returns (uint) {
    return type(uint).max - 1;
  }

  function maxWithdraw(address owner) public view virtual override returns (uint) {
    return convertToAssets(balanceOf(owner));
  }

  function maxRedeem(address owner) public view virtual override returns (uint) {
    return balanceOf(owner);
  }

  ///////////////////////////////////////////////////////////////
  //                INTERNAL HOOKS LOGIC
  ///////////////////////////////////////////////////////////////

  function beforeWithdraw(uint assets, uint shares) internal virtual {}

  function afterDeposit(uint assets, uint shares) internal virtual {}

  /**
 * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
  uint[49] private __gap;
}
