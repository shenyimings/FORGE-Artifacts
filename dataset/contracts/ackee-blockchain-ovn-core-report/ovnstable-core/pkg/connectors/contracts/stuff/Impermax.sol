// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0 <0.9.0;

interface IImpermaxRouter {

    function mint(address poolToken, uint256 amount, address to, uint256 deadline) external;

    function redeem(address poolToken, uint256 tokens, address to, uint256 deadline, bytes memory permitData) external;

    function getUniswapV2Pair(address underlying) external view returns (address);

    function getBorrowable(address uniswapV2Pair, uint8 index) external view returns (address borrowable);

    function getCollateral(address uniswapV2Pair) external view returns (address collateral);

    function getLendingPool(address uniswapV2Pair) external view returns (address collateral, address borrowableA, address borrowableB);

}

interface IPoolToken {

    /*** Impermax ERC20 ***/

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function totalBalance() external view returns (uint);
    function exchangeRateLast() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function underlying() external view returns (address);

    function exchangeRate() external  returns (uint);

}
