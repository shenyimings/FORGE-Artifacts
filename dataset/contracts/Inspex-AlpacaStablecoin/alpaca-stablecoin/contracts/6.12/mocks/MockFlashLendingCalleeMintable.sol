pragma solidity 0.6.12;

import "../interfaces/IFlashLendingCallee.sol";
import "../interfaces/IBookKeeper.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "hardhat/console.sol";

contract MockFlashLendingCalleeMintable is IFlashLendingCallee, PausableUpgradeable {
  IBookKeeper public bookKeeper;

  // --- Init ---
  function initialize(address _bookKeeper) external initializer {
    PausableUpgradeable.__Pausable_init();

    bookKeeper = IBookKeeper(_bookKeeper);
  }

  function flashLendingCall(
    address caller,
    uint256 debtValueToRepay, // [rad]
    uint256 collateralAmountToLiquidate, // [wad]
    bytes calldata data
  ) external override {
    bookKeeper.mintUnbackedStablecoin(address(this), address(this), debtValueToRepay);
    if (data.length > 0) {
      (address treasuryAccount, bytes32 collateralPoolId) = abi.decode(data, (address, bytes32));
      bookKeeper.moveCollateral(collateralPoolId, address(this), treasuryAccount, collateralAmountToLiquidate);
    }
  }
}
