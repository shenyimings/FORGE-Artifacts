// SPDX-License-Identifier: GPL-3.0
//        .-.                               .-.
//       / (_)         /      /       .--.-'
//      /      .-. ---/------/---.-. (  (_)`)    (  .-.   .-.
//     /      (  |   /      /  ./.-'_ `-.  /  .   )(  |   /  )
//  .-/.    .-.`-'-'/      /   (__.'_    )(_.' `-'  `-'-'/`-'
// (_/ `-._.                       (_.--'               /

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/IBeanBag.sol";
import "./interfaces/ILATTE.sol";

contract BeanBagV2 is ERC20Upgradeable, IBeanBag, OwnableUpgradeable {
  /// @notice latte token
  ILATTE public latte;

  function initialize(ILATTE _latte) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ERC20Upgradeable.__ERC20_init("Bean Token V2", "BEANV2");

    latte = _latte;
  }

  /// @dev A generic transfer function
  /// @param _to The address of the account that will be credited
  /// @param _amount The amount to be moved
  function transfer(address _to, uint256 _amount) public virtual override returns (bool) {
    _transfer(_msgSender(), _to, _amount);
    return true;
  }

  /// @dev A generic transferFrom function
  /// @param _from The address of the account that will be debited
  /// @param _to The address of the account that will be credited
  /// @param _amount The amount to be moved
  function transferFrom(
    address _from,
    address _to,
    uint256 _amount
  ) public virtual override returns (bool) {
    _transfer(_from, _to, _amount);
    _approve(
      _from,
      _msgSender(),
      allowance(_from, _msgSender()).sub(_amount, "BeanBagV2::transferFrom::transfer amount exceeds allowance")
    );
    return true;
  }

  /// @notice Mint `_amount` BEAN to `_to`. Must only be called by MasterBarista.
  /// @param _to The address to receive BEAN
  /// @param _amount The amount of BEAN that will be mint
  function mint(address _to, uint256 _amount) external override onlyOwner {
    _mint(_to, _amount);
  }

  /// @notice Burn `_amount` BEAN to `_from`. Must only be called by MasterBarista.
  /// @param _from The address to burn BEAN from
  /// @param _amount The amount of BEAN that will be burned
  function burn(address _from, uint256 _amount) external override onlyOwner {
    _burn(_from, _amount);
  }

  /// @notice Safe LATTE transfer function, just in case if rounding error causes pool to not have enough LATTEs.
  /// @param _to The address to transfer LATTE to
  /// @param _amount The amount to transfer to
  function safeLatteTransfer(address _to, uint256 _amount) external override onlyOwner {
    uint256 _latteBal = latte.balanceOf(address(this));
    if (_amount > _latteBal) {
      latte.transfer(_to, _latteBal);
    } else {
      latte.transfer(_to, _amount);
    }
  }
}
