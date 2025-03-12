// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// support only token with 3 coins
interface ICurveTokenV3Remover {
  function remove_liquidity(
    uint256 _token_amount,
    uint256[3] memory _min_amounts,
    bool _use_underlying
  ) external returns (uint256[3] memory amounts);

  function underlying_coins(uint256 index) external returns (address);
}
