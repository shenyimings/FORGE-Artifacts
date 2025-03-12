pragma solidity 0.6.12;

import "../flash-mint/base/FlashLoanReceiverBase.sol";

contract MockMyFlashLoan is FlashLoanReceiverBase {
  // --- Init ---
  constructor(address _flash) public FlashLoanReceiverBase(_flash) {}

  function onFlashLoan(
    address initiator,
    address token,
    uint256 amount,
    uint256 fee,
    bytes calldata data
  ) external override returns (bytes32) {
    return CALLBACK_SUCCESS;
  }

  function onBookKeeperFlashLoan(
    address initiator,
    uint256 amount,
    uint256 fee,
    bytes calldata data
  ) external override returns (bytes32) {
    return CALLBACK_SUCCESS_BOOK_KEEPER_STABLE_COIN;
  }
}
