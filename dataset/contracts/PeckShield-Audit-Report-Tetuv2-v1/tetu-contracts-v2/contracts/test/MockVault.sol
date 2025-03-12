// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../proxy/ControllableV3.sol";
import "../vault/ERC4626Upgradeable.sol";

contract MockVault is ERC4626Upgradeable, ControllableV3 {
  using FixedPointMathLib for uint;
  using SafeERC20 for IERC20;

  uint constant public FEE_DENOMINATOR = 100;

  address public strategy;
  uint public fee;


  function init(
    address controller_,
    IERC20 _asset,
    string memory _name,
    string memory _symbol,
    address _strategy,
    uint _fee
  ) external initializer {
    __ERC4626_init(_asset, _name, _symbol);
    __Controllable_init(controller_);
    strategy = _strategy;
    fee = _fee;
  }

  /*//////////////////////////////////////////////////////////////
  //                  ACCOUNTING LOGIC
  //////////////////////////////////////////////////////////////*/

  function totalAssets() public view override returns (uint) {
    return _asset.balanceOf(address(this)) + _asset.balanceOf(strategy);
  }

  function previewDeposit(uint assets) public view virtual override returns (uint) {
    uint shares = convertToShares(assets);
    return shares - (shares * fee / FEE_DENOMINATOR);
  }

  function previewMint(uint shares) public view virtual override returns (uint) {
    uint supply = totalSupply();
    if (supply != 0) {
      uint assets = shares.mulDivUp(totalAssets(), supply);
      return assets * FEE_DENOMINATOR / (FEE_DENOMINATOR - fee);
    } else {
      return shares * FEE_DENOMINATOR / (FEE_DENOMINATOR - fee);
    }
  }

  function previewWithdraw(uint assets) public view virtual override returns (uint) {
    uint supply = totalSupply();
    uint _totalAssets = totalAssets();
    if (_totalAssets == 0) {
      return assets;
    }
    uint shares = assets.mulDivUp(supply, _totalAssets);
    shares = shares * FEE_DENOMINATOR / (FEE_DENOMINATOR - fee);
    return supply == 0 ? assets : shares;
  }

  function previewRedeem(uint shares) public view virtual override returns (uint) {
    shares = shares - (shares * fee / FEE_DENOMINATOR);
    return convertToAssets(shares);
  }

  ///////////////////////////////////////////////////////////////
  //           DEPOSIT/WITHDRAWAL LIMIT LOGIC
  ///////////////////////////////////////////////////////////////

  function maxDeposit(address) public pure override returns (uint) {
    return 100 * 1e18;
  }

  function maxMint(address) public pure override returns (uint) {
    return 100 * 1e18;
  }

  function maxWithdraw(address) public pure override returns (uint) {
    return 100 * 1e18;
  }

  function maxRedeem(address) public pure virtual override returns (uint) {
    return 100 * 1e18;
  }

  ///////////////////////////////////////////////////////////////
  //                INTERNAL HOOKS LOGIC
  ///////////////////////////////////////////////////////////////

  function beforeWithdraw(uint assets, uint) internal override {
    uint balance = _asset.balanceOf(address(this));
    if (balance < assets) {
      require(_asset.balanceOf(strategy) >= assets - balance, "Strategy has not enough balance");
      // it is stub logic for EOA
      _asset.safeTransferFrom(strategy, address(this), assets - balance);
    }
  }

  function afterDeposit(uint assets, uint) internal override {
    _asset.safeTransfer(strategy, assets / 2);
  }

}
