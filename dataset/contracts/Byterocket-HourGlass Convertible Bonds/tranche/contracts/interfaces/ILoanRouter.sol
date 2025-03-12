pragma solidity 0.8.3;

import "./IBondController.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Router for creating loans with tranche
 */
interface ILoanRouter {
    /**
     * @dev Borrow against a given bond, wrapping the raw collateral into a ButtonToken first
     * @param underlyingAmount The amount of collateral to deposit into the bond
     * @param bond The bond to borrow from
     * @param currency The asset to borrow
     * @param sales The number of tranche tokens to sell, in tranche index order
     * @param minOutput The minimum amount of currency to get out, reverts if not met
     */
    function wrapAndBorrow(
        uint256 underlyingAmount,
        IBondController bond,
        IERC20 currency,
        uint256[] memory sales,
        uint256 minOutput
    ) external returns (uint256 amountOut);

    /**
     * @dev Borrow as much as possible against a given bond, wrapping the raw collateral into a ButtonToken first
     * @param underlyingAmount The amount of collateral to deposit into the bond
     * @param bond The bond to borrow from
     * @param currency The asset to borrow
     * @param minOutput The minimum amount of currency to get out, reverts if not met
     */
    function wrapAndBorrowMax(
        uint256 underlyingAmount,
        IBondController bond,
        IERC20 currency,
        uint256 minOutput
    ) external returns (uint256 amountOut);

    /**
     * @dev Borrow against a given bond
     * @param amount The amount of collateral to deposit into the bond
     * @param bond The bond to borrow from
     * @param currency The asset to borrow
     * @param sales The number of tranche tokens to sell, in tranche index order
     * @param minOutput The minimum amount of currency to get out, reverts if not met
     */
    function borrow(
        uint256 amount,
        IBondController bond,
        IERC20 currency,
        uint256[] memory sales,
        uint256 minOutput
    ) external returns (uint256 amountOut);

    /**
     * @dev Borrow as much as possible against a given bond
     * @param amount The amount of collateral to deposit into the bond
     * @param bond The bond to borrow from
     * @param currency The asset to borrow
     * @param minOutput The minimum amount of currency to get out, reverts if not met
     */
    function borrowMax(
        uint256 amount,
        IBondController bond,
        IERC20 currency,
        uint256 minOutput
    ) external returns (uint256 amountOut);
}
