pragma solidity 0.5.16;

import "@chainlink/contracts/src/v0.5/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract IUniswapRouterV2 {
  function getAmountsOut(uint256 amountIn, address[] memory path) public view returns (uint256[] memory amounts);
}

contract UniswapOracle {

  using SafeMath for uint256;

  address public constant oracle = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  address public constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public ausc;
  address[] public path;

  constructor (address token) public {
    ausc = token;
    path = [ausc, weth, usdc];
  }

  function getPriceAUSC() public view returns (bool, uint256) {
    // returns the price with 6 decimals, but we want 18
    uint256[] memory amounts = IUniswapRouterV2(oracle).getAmountsOut(1e18, path);
    return (ausc != address(0), amounts[2].mul(1e12));
  }
}

