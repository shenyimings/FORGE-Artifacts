// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/StdCheats.sol";
import { IERC20 } from "src/interfaces/IERC20.sol";

contract MockPancakeV3Worker is StdCheats {
  address public exeuctor;
  address public token0;
  address public token1;
  uint256 public nftTokenId;

  uint256 private decreasedToken0;
  uint256 private decreasedToken1;

  constructor(address _token0, address _token1, uint256 _nftTokenId, address _exeuctor) {
    token0 = _token0;
    token1 = _token1;
    nftTokenId = _nftTokenId;
    exeuctor = _exeuctor;
  }

  function transferToExecutor(address _token, uint256 _amount) external {
    IERC20(_token).transfer(exeuctor, _amount);
  }

  function setDecreasedTokens(uint256 amount0, uint256 amount1) external {
    decreasedToken0 = amount0;
    decreasedToken1 = amount1;
  }

  function decreasePosition(uint128 /* _liquidity */ ) external returns (uint256, uint256) {
    deal(token0, address(this), IERC20(token0).balanceOf(address(this)) + decreasedToken0);
    deal(token1, address(this), IERC20(token1).balanceOf(address(this)) + decreasedToken1);
    return (decreasedToken0, decreasedToken1);
  }
}
