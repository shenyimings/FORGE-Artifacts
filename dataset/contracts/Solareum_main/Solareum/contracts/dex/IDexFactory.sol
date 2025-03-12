// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

interface IDexFactory {
  function createPair(
    address tokenA,
    address tokenB
  ) external returns (address pair);

  function getPair(
    address tokenA,
    address tokenB
  ) external view returns (address pair);
}