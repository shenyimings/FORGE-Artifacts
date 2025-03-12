pragma solidity 0.8.3;

import "./IBondController.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Router for creating loans with tranche
 */
interface IWethLoanRouter {
    /**
     * @notice Borrow against a given bond, wrapping the raw ETH collateral into a WETH ButtonToken first
     * @param bond The bond to borrow from
     * @param currency The asset to borrow
     * @param sales The number of tranche tokens to sell, in tranche index order
     * @param minOutput The minimum amount of currency to get out, reverts if not met
     */
    function wrapAndBorrow(
        IBondController bond,
        IERC20 currency,
        uint256[] memory sales,
        uint256 minOutput
    ) external payable returns (uint256 amountOut);

    /**
     * @notice Borrow as much as possible against a given bond,
     *  wrapping the raw ETH collateral into a WETH ButtonToken first
     * @param bond The bond to borrow from
     * @param currency The asset to borrow
     * @param minOutput The minimum amount of currency to get out, reverts if not met
     */
    function wrapAndBorrowMax(
        IBondController bond,
        IERC20 currency,
        uint256 minOutput
    ) external payable returns (uint256 amountOut);
}
