// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ICurveTokenV5Remover {
  function remove_liquidity(
    uint256 _token_amount,
    uint256[5] memory _min_amounts,
    address _receiver
  ) external;

  function underlying_coins(uint256 index) external returns (address);
}
