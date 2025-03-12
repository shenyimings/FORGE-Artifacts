// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "mock-contract/MockContract.sol";
import "./MockERC20.sol";
import "../../../../lib/solmate/src/utils/SafeTransferLib.sol";
import "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

contract MockUniswapV2Router01 is MockContract {
  using SafeTransferLib for address;
  using FixedPointMathLib for uint256;

  struct RemoveLiquidityExchangeRate {
    uint256 baseToken;
    uint256 nativeToken;
  }

  mapping(address => address) public baseTokensLpAddress;
  mapping(address => RemoveLiquidityExchangeRate) public lpRemoveLiquidityRate;

  function mockMapBaseTokenWithLPToken(address baseToken, address lpToken)
    public
  {
    baseTokensLpAddress[baseToken] = lpToken;
  }

  function mockSetLpRemoveLiquidityRate(
    address lpToken,
    uint256 baseTokenRate,
    uint256 nativeRate
  ) public {
    lpRemoveLiquidityRate[lpToken] = RemoveLiquidityExchangeRate({
      baseToken: baseTokenRate,
      nativeToken: nativeRate
    });
  }

  function removeLiquidityETH(
    address token,
    uint256 liquidity,
    uint256, /** amountTokenMin **/
    uint256, /** amountETHMin **/
    address to,
    uint256 /** deadline */
  ) external returns (uint256 amountToken, uint256 amountETH) {
    address lpToken = baseTokensLpAddress[token];
    MockERC20(payable(lpToken)).transferFrom(
      msg.sender,
      address(this),
      liquidity
    );

    RemoveLiquidityExchangeRate
      memory removeLiquidityRate = lpRemoveLiquidityRate[lpToken];
    uint256 baseTokenAmount = removeLiquidityRate.baseToken.mulWadDown(
      liquidity
    );
    uint256 nativeTokenAmount = removeLiquidityRate.nativeToken.mulWadDown(
      liquidity
    );

    MockERC20(payable(token)).transfer(to, baseTokenAmount);
    msg.sender.safeTransferETH(nativeTokenAmount);

    return (baseTokenAmount, nativeTokenAmount);
  }

  function swapExactTokensForETH(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata, /** path */
    address, /** to */
    uint256 /** deadline */
  ) external payable returns (uint256[] memory amounts) {
    uint256[] memory amountOuts = new uint256[](1);
    amountOuts[0] = amountOutMin;
    msg.sender.safeTransferETH(amountIn);
    return (amountOuts);
  }
}
