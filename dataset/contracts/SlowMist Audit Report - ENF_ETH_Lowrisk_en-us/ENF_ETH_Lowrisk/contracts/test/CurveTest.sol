// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

interface ICurvePool {
    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external;
}

interface ICurvePoolToETH {
    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 min_dy,
        bool use_eth
    ) external;
}

contract CurveTest {
    address pool = 0x8301AE4fc9c624d1D396cbDAa1ed877821D7C511;
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint256 i = 1;
    uint256 j = 0;

    address crv = 0xD533a949740bb3306d119CC777fa900bA034cd52;

    receive() external payable {}

    constructor() {}

    function swap(uint256 amount) public {
        IERC20(crv).transferFrom(msg.sender, address(this), amount);

        IERC20(crv).approve(pool, 0);
        IERC20(crv).approve(pool, 100000000000000000000000000000000000);

        ICurvePoolToETH(pool).exchange(i, j, amount, 0, true);
        uint256 swapped = address(this).balance;
        console.log("ETH out: ", swapped);
        uint256 wethOut = IERC20(weth).balanceOf(address(this));
        console.log("WETH out: ", wethOut);
    }
}
