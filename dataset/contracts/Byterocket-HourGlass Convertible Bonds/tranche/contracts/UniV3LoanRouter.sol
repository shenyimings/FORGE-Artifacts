pragma solidity ^0.8.3;

import "./LoanRouter.sol";
import "./interfaces/IBondController.sol";
import "./interfaces/ITranche.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev Loan router for the UniswapV3 AMM
 */
contract UniV3LoanRouter is LoanRouter {
    ISwapRouter public immutable uniswapV3Router;

    constructor(ISwapRouter _uniswapV3Router) {
        uniswapV3Router = _uniswapV3Router;
    }

    /**
     * @inheritdoc LoanRouter
     */
    function _swap(
        address input,
        address output,
        uint256 amount
    ) internal override {
        SafeERC20.safeIncreaseAllowance(IERC20(input), address(uniswapV3Router), amount);
        uniswapV3Router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams(
                address(input),
                address(output),
                10000,
                address(this),
                block.timestamp,
                amount,
                0,
                0
            )
        );
    }
}
