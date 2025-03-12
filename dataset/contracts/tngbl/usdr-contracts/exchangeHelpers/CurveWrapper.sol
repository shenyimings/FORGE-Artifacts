// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";

import "../constants/roles.sol";

interface CurveExchanges {
    function underlying_coins(uint256 i) external returns (address);

    // like getAmountsOut
    function get_exchange_amount(
        address pool,
        address inputToken,
        address outputToken,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    // like getAmountsIn
    function get_input_amount(
        address pool,
        address inputToken,
        address outputToken,
        uint256 amountOut
    ) external view returns (uint256 amountIn);

    function exchange(
        address pool,
        address inputToken,
        address outputToken,
        uint256 amountIn,
        uint256 expectedOut
    ) external returns (uint256 amountReceived);
}

interface CurveRegistry {
    function find_pool_for_coins(address fromToken, address toToken)
        external
        view
        returns (address pool);

    function get_coin_indices(
        address pool,
        address fromToken,
        address toToken
    )
        external
        view
        returns (
            int128 fromIndex,
            int128 toIndex,
            bool metaPool
        );
}

contract CurveWrapper is AccessControl {
    using SafeERC20 for IERC20;

    mapping(bytes => address) public pools;

    CurveRegistry public immutable curveRegistry =
        CurveRegistry(0x094d12e5b541784701FD8d65F11fc0598FBC6332);
    CurveExchanges public immutable curveExchange =
        CurveExchanges(0xa522deb6F17853F3a97a65d0972a50bDC3B1AFFF);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ROUTER_POLICY_ROLE, msg.sender);
    }

    function addPoolForTokens(
        address pool,
        address tokenInAddress,
        address tokenOutAddress
    ) external onlyRole(ROUTER_POLICY_ROLE) {
        bytes memory tokenized = abi.encodePacked(
            tokenInAddress,
            tokenOutAddress
        );
        bytes memory tokenizedReverse = abi.encodePacked(
            tokenOutAddress,
            tokenInAddress
        );
        pools[tokenized] = pool;
        pools[tokenizedReverse] = pool;
    }

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amountsIn)
    {
        require(path.length == 2, "invalid path length");
        bytes memory tokenized = abi.encodePacked(path[0], path[1]);
        address pool = pools[tokenized]; // curveRegistry.find_pool_for_coins(path[0], path[1]);
        require(pool != address(0), "pool missing");

        amountsIn = new uint256[](2);
        amountsIn[0] = curveExchange.get_input_amount(
            pool,
            path[0],
            path[1],
            amountOut
        );
        amountsIn[1] = amountOut;
    }

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amountsOut)
    {
        require(path.length == 2, "invalid path length");
        bytes memory tokenized = abi.encodePacked(path[0], path[1]);
        address pool = pools[tokenized]; // curveRegistry.find_pool_for_coins(path[0], path[1]);
        require(pool != address(0), "pool missing");

        amountsOut = new uint256[](2);
        amountsOut[0] = amountIn;
        amountsOut[1] = curveExchange.get_exchange_amount(
            pool,
            path[0],
            path[1],
            amountIn
        );
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address, //to,
        uint256 //deadline
    ) external returns (uint256[] memory amountsOut) {
        require(path.length == 2, "invalid path length");
        bytes memory tokenized = abi.encodePacked(path[0], path[1]);
        address pool = pools[tokenized]; // curveRegistry.find_pool_for_coins(path[0], path[1]);
        require(pool != address(0), "pool missing");
        // take the input token
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        //approve the exchange
        IERC20(path[0]).approve(address(curveExchange), amountIn);

        amountsOut = new uint256[](2);
        amountsOut[0] = amountIn;
        amountsOut[1] = curveExchange.exchange(
            pool,
            path[0],
            path[1],
            amountIn,
            amountOutMin
        );
        IERC20(path[1]).safeTransfer(msg.sender, amountsOut[1]);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountIn,
        address[] calldata path,
        address, //to,
        uint256 //deadline
    ) external returns (uint256[] memory amountsOut) {
        require(path.length == 2, "invalid path length");
        bytes memory tokenized = abi.encodePacked(path[0], path[1]);
        address pool = pools[tokenized]; // curveRegistry.find_pool_for_coins(path[0], path[1]);
        require(pool != address(0), "pool missing");
        // take the input token
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        //approve the exchange
        IERC20(path[0]).approve(address(curveExchange), amountIn);

        amountsOut = new uint256[](2);
        amountsOut[0] = amountIn;
        amountsOut[1] = curveExchange.exchange(
            pool,
            path[0],
            path[1],
            amountIn,
            amountOut
        );
        IERC20(path[1]).safeTransfer(msg.sender, amountsOut[1]);
    }
}
