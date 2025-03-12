// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

interface ICurvePool {
    function exchange(
        uint256 _amount,
        address[6] memory _route,
        uint256[8] memory _indices,
        uint256 _min_received,
        address _receiver
    ) external payable;

    function get_exchange_routing(
        address _initial,
        address _target,
        uint256 _amount
    )
        external
        view
        returns (
            address[6] memory,
            uint256[8] memory,
            uint256
        );
}

contract CurveMultiTest {
    address pool = 0xfA9a30350048B2BF66865ee20363067c66f67e58;
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address crv = 0xD533a949740bb3306d119CC777fa900bA034cd52;

    address nullAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address[6] public ethBTC = [
        0x0000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000,
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
        0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
        0x0000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000
    ];

    address[6] public btcETH = [
        0x0000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000,
        0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
        0x0000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000
    ];

    address[6] public ethUSDC = [
        0x0000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000,
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
        0xdAC17F958D2ee523a2206206994597C13D831ec7,
        0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7,
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    ];

    uint256[8] ethBTCIndices = [0, 0, 0, 2, 1, 0, 0, 0];
    uint256[8] ethUSDCIndices = [0, 0, 0, 2, 0, 2, 1, 0];
    uint256[8] btcETHIndices = [0, 0, 0, 1, 2, 0, 0, 0];

    receive() external payable {}

    constructor() {}

    function swap(uint256 amount) public payable {
        // IERC20(crv).transferFrom(msg.sender, address(this), amount);

        // IERC20(crv).approve(pool, 0);
        // IERC20(crv).approve(pool, 100000000000000000000000000000000000);

        uint256 oldBTC = IERC20(wbtc).balanceOf(address(this));
        ICurvePool(pool).exchange{value: msg.value}(amount, ethBTC, ethBTCIndices, 0, address(this));

        uint256 newBTC = IERC20(wbtc).balanceOf(address(this));
        console.log("WBTC out: ", newBTC - oldBTC);

        IERC20(wbtc).approve(pool, 0);
        IERC20(wbtc).approve(pool, 100000000000000000000000000000000000);
        uint256 oldETH = address(msg.sender).balance;
        ICurvePool(pool).exchange(newBTC - oldBTC, btcETH, btcETHIndices, 700000000000000000, msg.sender);

        uint256 newETH = address(msg.sender).balance;
        console.log("ETH out: ", newETH - oldETH);
    }

    function swapUSDC(uint256 amount) public payable {
        // IERC20(crv).transferFrom(msg.sender, address(this), amount);

        // IERC20(crv).approve(pool, 0);
        // IERC20(crv).approve(pool, 100000000000000000000000000000000000);

        (, , uint256 amoutOut) = ICurvePool(pool).get_exchange_routing(nullAddr, usdc, amount);
        console.log("USDC OUt: ", amount, amoutOut);

        uint256 oldBal = IERC20(usdc).balanceOf(msg.sender);
        ICurvePool(pool).exchange{value: msg.value}(amount, ethUSDC, ethUSDCIndices, 0, msg.sender);

        uint256 newBal = IERC20(usdc).balanceOf(msg.sender);
        console.log("ETH out: ", newBal - oldBal);
    }
}
