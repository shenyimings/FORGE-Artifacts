pragma solidity 0.8.3;

import "./IBondController.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Router for creating loans with tranche
 */
interface IWamplLoanRouter {
    /**
     * @notice Borrow against a given bond, wrapping the raw AMPL collateral into a WAMPL ButtonToken first
     * @param amplAmount The amount of AMPL to deposit into the bond
     * @param bond The bond to borrow from
     * @param currency The asset to borrow
     * @param sales The number of tranche tokens to sell, in tranche index order
     * @param minOutput The minimum amount of currency to get out, reverts if not met
     */
    function wrapAndBorrow(
        uint256 amplAmount,
        IBondController bond,
        IERC20 currency,
        uint256[] memory sales,
        uint256 minOutput
    ) external returns (uint256 amountOut);

    /**
     * @notice Borrow as much as possible against a given bond,
     *  wrapping the raw ampl collateral into a WAMPL ButtonToken first
     * @param amplAmount The amount of AMPL to deposit into the bond
     * @param bond The bond to borrow from
     * @param currency The asset to borrow
     * @param minOutput The minimum amount of currency to get out, reverts if not met
     */
    function wrapAndBorrowMax(
        uint256 amplAmount,
        IBondController bond,
        IERC20 currency,
        uint256 minOutput
    ) external returns (uint256 amountOut);
}
