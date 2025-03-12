// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "../../interfaces/IUniswapV2Pair.sol";

contract MockUniswapV2Pair is IUniswapV2Pair {
    address public override token0;
    address public override token1;
    uint256 public override price0CumulativeLast;
    uint256 public override price1CumulativeLast;
    uint112 public reserve0;
    uint112 public reserve1;
    uint32 public blockTimestampLast;

    constructor(address _token0, address _token1) public {
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves()
        external
        override
        view
        returns (
            uint112,
            uint112,
            uint32
        )
    {
        return (reserve0, reserve1, blockTimestampLast);
    }

    function setPrice0CumulativeLast(uint256 _price0CumulativeLast) external {
        price0CumulativeLast = _price0CumulativeLast;
    }

    function setPrice1CumulativeLast(uint256 _price1CumulativeLast) external {
        price1CumulativeLast = _price1CumulativeLast;
    }

    function setReserve0(uint112 _reserve0) external {
        reserve0 = _reserve0;
    }

    function setReserve1(uint112 _reserve1) external {
        reserve1 = _reserve1;
    }

    function setBlockTimestampLast(uint32 _blockTimestampLast) external {
        blockTimestampLast = _blockTimestampLast;
    }
}
