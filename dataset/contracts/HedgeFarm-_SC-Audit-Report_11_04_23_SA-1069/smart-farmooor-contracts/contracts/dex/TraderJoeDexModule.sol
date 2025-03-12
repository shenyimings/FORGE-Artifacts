// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../common/Rescuable.sol";
import "./interface/IDex.sol";
import "./interface/traderjoe/IJoeRouter02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TraderJoeDexModule is IDex, Ownable, Rescuable {
    using SafeERC20 for IERC20;

    IJoeRouter02 public immutable router;

    uint256 public constant DEADLINE_DELTA = 10;
    uint256 public constant AMOUNT_OUT_MIN = 0;

    mapping(address => mapping(address => address[])) public routes;

    constructor(address _router, address[][] memory _routes) {
        router = IJoeRouter02(_router);
        setRoutes(_routes);
    }

    /**
     * @notice  Get a quote for a Swap
     * @dev     Can be used for both ERC20 and native token. Use the wrapped native token to get a preview of a native token swap.
     * @param   _amountIn  Token amount in
     * @param   _in  Token address In
     * @param   _out  Token address Out
     * @return  amountOut  Amount of tokens out
     */
    //
    function swapPreview(uint256 _amountIn, address _in, address _out) public view returns (uint amountOut) {
        if (_amountIn > 0) {
            uint256[] memory amounts = router.getAmountsOut(_amountIn, routes[_in][_out]);
            return amounts[routes[_in][_out].length - 1];
        } else {
            return 0;
        }
    }

    /**
     * @notice  Swap between two ERC20 tokens
     * @param   _amountIn  Token amount in
     * @param   _in  Token address In
     * @param   _out  Token address Out
     * @param   _to  Address of the receiver of amounts
     * @return  amounts  Amounts of token out
     */
    function swap(uint256 _amountIn, address _in, address _out, address _to) external returns (uint[] memory amounts) {
        if (swapPreview(_amountIn, _in, _out) > 0) {
            IERC20(_in).safeTransferFrom(msg.sender, address(this), _amountIn);
            return router.swapExactTokensForTokens(_amountIn, AMOUNT_OUT_MIN, routes[_in][_out], _to, block.timestamp + DEADLINE_DELTA);
        }
    }

    /**
     * @notice  Swap between two ERC20 tokens with slippage tolerance
     * @param   _amountIn  Token amount in
     * @param   _amountOutMin  Minimum amount out - slippage tolerance
     * @param   _in  Token address In
     * @param   _out  Token address Out
     * @param   _to  Address of the receiver of amounts
     * @return  amounts  Amounts of token out
     */
    function swapSlippageMin(uint256 _amountIn, uint256 _amountOutMin, address _in, address _out, address _to) external returns (uint[] memory amounts) {
        if (swapPreview(_amountIn, _in, _out) > 0) {
            IERC20(_in).safeTransferFrom(msg.sender, address(this), _amountIn);
            return router.swapExactTokensForTokens(_amountIn, _amountOutMin, routes[_in][_out], _to, block.timestamp + DEADLINE_DELTA);
        }
    }

    /**
     * @notice  Add new route or update existing route
     * @param   _routes  Routes to add or to update
     */
    function setRoutes(address[][] memory _routes) public onlyOwner {
        for (uint8 i = 0; i < _routes.length; i++) {
            routes[_routes[i][0]][_routes[i][_routes[i].length - 1]] = _routes[i];
            uint256 allowance = IERC20(_routes[i][0]).allowance(address(this), address(router));
            if (allowance == 0) {
                IERC20(_routes[i][0]).safeApprove(address(router), type(uint256).max);
            }
        }
    }

    /**
     * @notice  Delete routes
     * @param   _routes  Routes to delete
     */
    function deleteRoutes(address[][] memory _routes) public onlyOwner {
        for (uint8 i = 0; i < _routes.length; i++) {
            delete routes[_routes[i][0]][_routes[i][_routes[i].length - 1]];
        }
    }

    /**
     * @notice  Get swap route for a given pair
     * @param   _in  Token address In
     * @param   _out  Token address Out
     * @return  route  Swap route for a given pair
     */
    function getRoute(address _in, address _out) external view returns (address[] memory route) {
        return routes[_in][_out];
    }

    /**
    * @notice  Rescue a stuck ERC20 token
    */
    function rescueToken(address token) external onlyOwner {
        _rescueToken(token);
    }

    /**
    * @notice  Rescue native tokens
    */
    function rescueNative() external onlyOwner {
        _rescueNative();
    }
}
