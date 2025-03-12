// SPDX-License-Identifier: AGPL-3.0-or-later
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/

pragma solidity 0.6.12;

import "../FlashMintModule.sol";
import "../../interfaces/IBookKeeperFlashBorrower.sol";
import "../../interfaces/IERC3156FlashBorrower.sol";

abstract contract FlashLoanReceiverBase is IBookKeeperFlashBorrower, IERC3156FlashBorrower {
  FlashMintModule public flash;

  bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
  bytes32 public constant CALLBACK_SUCCESS_BOOK_KEEPER_STABLE_COIN =
    keccak256("BookKeeperFlashBorrower.onBookKeeperFlashLoan");

  // --- Init ---
  constructor(address _flash) public {
    flash = FlashMintModule(_flash);
  }

  // --- Math ---
  uint256 constant RAY = 10**27;

  function rad(uint256 _wad) internal pure returns (uint256) {
    return mul(_wad, RAY);
  }

  function add(uint256 _x, uint256 _y) internal pure returns (uint256 _z) {
    require((_z = _x + _y) >= _x);
  }

  function mul(uint256 _x, uint256 _y) internal pure returns (uint256 _z) {
    require(_y == 0 || (_z = _x * _y) / _y == _x);
  }

  // --- Helper Functions ---
  function approvePayback(uint256 _amount) internal {
    // Lender takes back the stablecoin as per ERC 3156 spec
    flash.stablecoin().approve(address(flash), _amount);
  }

  function payBackBookKeeper(uint256 _amount) internal {
    // Lender takes back the stablecoin as per ERC 3156 spec
    flash.bookKeeper().moveStablecoin(address(this), address(flash), _amount);
  }
}
