pragma solidity ^0.8.3;

import "../interfaces/ILoanRouter.sol";
import "../interfaces/IBondController.sol";
import "../interfaces/ITranche.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev Purposely Bad Loan router to test failure conditions of Wampl/Weth Loan Routers.
 */
/* solhint-disable */
contract BadLoanRouter is ILoanRouter {
    uint256 public constant MAX_UINT256 = type(uint256).max;

    /**
     * @inheritdoc ILoanRouter
     */
    function wrapAndBorrow(
        uint256 underlyingAmount,
        IBondController bond,
        IERC20 currency,
        uint256[] memory sales,
        uint256 minOutput
    ) external override returns (uint256 amountOut) {
        return minOutput - 1;
    }

    /**
     * @inheritdoc ILoanRouter
     */
    function wrapAndBorrowMax(
        uint256 underlyingAmount,
        IBondController bond,
        IERC20 currency,
        uint256 minOutput
    ) external override returns (uint256 amountOut) {
        return minOutput - 1;
    }

    /**
     * @inheritdoc ILoanRouter
     */
    function borrow(
        uint256 amount,
        IBondController bond,
        IERC20 currency,
        uint256[] memory sales,
        uint256 minOutput
    ) external override returns (uint256 amountOut) {
        return minOutput - 1;
    }

    /**
     * @inheritdoc ILoanRouter
     */
    function borrowMax(
        uint256 amount,
        IBondController bond,
        IERC20 currency,
        uint256 minOutput
    ) external override returns (uint256 amountOut) {
        return minOutput - 1;
    }
}
