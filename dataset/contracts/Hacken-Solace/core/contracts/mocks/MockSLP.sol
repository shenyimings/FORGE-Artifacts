// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


/**
 * @title Mock ERC-20
 * @author solace.fi
 * @notice Mock ERC-20 is only used to test the master contract.
 */
contract MockSLP is ERC20 {
    using SafeERC20 for IERC20;

    address internal _token0;
    address internal _token1;
    uint112 internal _reserve0;
    uint112 internal _reserve1;

    /**
     * @notice Constructs the Mock Token contract.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param supply The amount of supply for the token.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply,
        address token0_,
        address token1_,
        uint112 reserve0_,
        uint112 reserve1_
    ) ERC20(name, symbol) {
        _token0 = token0_;
        _token1 = token1_;
        _reserve0 = reserve0_;
        _reserve1 = reserve1_;
        _mint(msg.sender, supply);
    }

  
  /**
   * @notice Returns the first pair token.
   * @return token The address of the first pair token.
   */
  function token0() external view returns (address token) {
      return _token0;
  }

  /**
   * @notice Returns the second pair token.
   * @return token The address of the second pair token.
   */
  function token1() external view returns (address token) {
      return _token1;
  }

  /**
   * @notice Returns LP token reserves.
   * @return _reserve0
   * @return _reserve1
   * @return _blockTimestampLast 
  */
  function getReserves() external pure returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
    return (_reserve0, _reserve1, 0);
  }
}