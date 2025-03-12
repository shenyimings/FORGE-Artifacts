// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "./constants/addresses.sol";
import "./interfaces/IPriceOracle.sol";
import "./AddressAccessor.sol";

interface IBaseOracle {
    function consult(
        address tokenIn,
        uint128 amountIn,
        address tokenOut,
        uint24 secondsAgo
    ) external view returns (uint256);
}

contract TNGBLPriceOracle is AddressAccessor, IPriceOracle {
    address public immutable baseOracle;
    address public immutable baseDenominatorToken;

    uint24 public oracleLookBackPeriod;

    address private _router;
    address private _output;
    address[] private _path;

    constructor(address baseOracle_, address baseDenominatorToken_) {
        baseOracle = baseOracle_;
        baseDenominatorToken = baseDenominatorToken_;
        oracleLookBackPeriod = 60;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function quote(uint256 amountIn) external view returns (uint256 amountOut) {
        if (amountIn == 0) return 0;
        address tngbl = addressProvider.getAddress(TNGBL_ADDRESS);
        try
            IBaseOracle(baseOracle).consult(
                tngbl,
                uint128(amountIn),
                baseDenominatorToken,
                oracleLookBackPeriod
            )
        returns (uint256 amount) {
            amountOut = amount;
        } catch {
            amountOut = IBaseOracle(baseOracle).consult(
                tngbl,
                uint128(amountIn),
                baseDenominatorToken,
                1
            );
        }
        if (baseDenominatorToken != _output) {
            uint256[] memory amountsOut = IUniswapV2Router02(_router)
                .getAmountsOut(amountOut, _path);
            amountOut = amountsOut[amountsOut.length - 1];
        }
    }

    function setOracleLookBackPeriod(uint24 secondsAgo)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        oracleLookBackPeriod = secondsAgo;
    }

    function setSwapRoute(address router, address[] memory path)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(path[0] == baseDenominatorToken, "invalid path");
        _router = router;
        _path = path;
        _output = path[path.length - 1];
        address underlying = addressProvider.getAddress(UNDERLYING_ADDRESS);
        require(_output == underlying, "invalid path");
    }
}
