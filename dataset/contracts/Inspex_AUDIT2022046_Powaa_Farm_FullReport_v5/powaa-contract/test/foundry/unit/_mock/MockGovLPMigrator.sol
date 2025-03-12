// SPDX-License-Identifier: BUSL1.1
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../../../contracts/v0.8.16/interfaces/ILp.sol";
import "../../../../lib/solmate/src/utils/SafeTransferLib.sol";
import "../../../../lib/mock-contract/contracts/MockContract.sol";

contract MockGovLPMigrator is MockContract {
  using SafeTransferLib for address;
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  function execute(bytes calldata _data) external {
    address token = abi.decode(_data, (address));
    address baseToken = address(ILp(token).token0()) != address(WETH9)
      ? address(ILp(token).token0())
      : address(ILp(token).token1());

    uint256 tokenBalance = IERC20(token).balanceOf(address(this));
    uint256 halfAmount = tokenBalance.div(2);

    msg.sender.safeTransferETH(halfAmount);
    IERC20(baseToken).safeTransfer(msg.sender, halfAmount);
  }
}
