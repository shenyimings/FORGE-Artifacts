// SPDX-License-Identifier: BUSL1.1
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../../../lib/solmate/src/utils/SafeTransferLib.sol";
import "../../../../lib/mock-contract/contracts/MockContract.sol";

import "./MockERC20.sol";

contract MockV3SwapRouter is MockContract {
  using SafeTransferLib for address;
  using SafeMath for uint256;

  mapping(address => uint256) exchangeRate;

  function mockSetSwapRate(address _token, uint256 _exchangeRate) external {
    exchangeRate[_token] = _exchangeRate;
  }

  struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
  }

  function exactInputSingle(ExactInputSingleParams calldata params)
    external
    payable
    returns (uint256 amountOut)
  {
    uint256 tokenBalance = MockERC20(payable(params.tokenIn)).balanceOf(
      params.recipient
    );
    MockERC20(payable(params.tokenIn)).transferFrom(
      msg.sender,
      address(this),
      tokenBalance
    );

    uint256 swappedAmount = tokenBalance.mul(exchangeRate[params.tokenIn]).div(
      1 ether
    );
    MockERC20(payable(params.tokenOut)).transfer(msg.sender, swappedAmount);

    return swappedAmount;
  }

  struct ExactInputParams {
    bytes path;
    address recipient;
    uint256 amountIn;
    uint256 amountOutMinimum;
  }

  function exactInput(ExactInputParams calldata params)
    external
    payable
    returns (uint256 amountOut)
  {
    params;
    return uint256(0);
  }

  struct ExactOutputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 amountOut;
    uint256 amountInMaximum;
    uint160 sqrtPriceLimitX96;
  }

  function exactOutputSingle(ExactOutputSingleParams calldata params)
    external
    payable
    returns (uint256 amountIn)
  {
    params;
    return uint256(0);
  }

  struct ExactOutputParams {
    bytes path;
    address recipient;
    uint256 amountOut;
    uint256 amountInMaximum;
  }

  function exactOutput(ExactOutputParams calldata params)
    external
    payable
    returns (uint256 amountIn)
  {
    params;
    return uint256(0);
  }
}
