pragma solidity ^0.8.3;

import "./interfaces/ILoanRouter.sol";
import "./interfaces/IBondController.sol";
import "./interfaces/ITranche.sol";
import "./interfaces/IButtonWrapper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev Abstract Loan Router to allow loans to be created with different AMM implementations
 * Loans are created using a composition of ButtonTranche and an AMM for Tranche token liquidity
 * vs. a stablecoin. The specific AMM that we use may change, so concrete implementations
 * of this abstract contract can define a `swap` function to implement a composition with
 * the AMM of their choosing.
 */
abstract contract LoanRouter is ILoanRouter {
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
        IButtonWrapper wrapper = IButtonWrapper(bond.collateralToken());
        IERC20 underlying = IERC20(wrapper.underlying());
        SafeERC20.safeTransferFrom(underlying, msg.sender, address(this), underlyingAmount);
        underlying.approve(address(wrapper), underlyingAmount);
        uint256 wrapperAmount = wrapper.deposit(underlyingAmount);

        return _borrow(wrapperAmount, bond, IERC20(address(wrapper)), currency, sales, minOutput);
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
        uint256 trancheCount = bond.trancheCount();
        uint256[] memory sales = new uint256[](trancheCount);
        // sell all tokens except the last one (Z token)
        for (uint256 i = 0; i < trancheCount - 1; i++) {
            sales[i] = MAX_UINT256;
        }

        IButtonWrapper wrapper = IButtonWrapper(bond.collateralToken());
        IERC20 underlying = IERC20(wrapper.underlying());
        SafeERC20.safeTransferFrom(underlying, msg.sender, address(this), underlyingAmount);
        underlying.approve(address(wrapper), underlyingAmount);
        uint256 wrapperAmount = wrapper.deposit(underlyingAmount);

        return _borrow(wrapperAmount, bond, IERC20(address(wrapper)), currency, sales, minOutput);
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
        IERC20 collateral = IERC20(bond.collateralToken());
        SafeERC20.safeTransferFrom(collateral, msg.sender, address(this), amount);

        return _borrow(amount, bond, collateral, currency, sales, minOutput);
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
        uint256 trancheCount = bond.trancheCount();
        uint256[] memory sales = new uint256[](trancheCount);
        // sell all tokens except the last one (Z token)
        for (uint256 i = 0; i < trancheCount - 1; i++) {
            sales[i] = MAX_UINT256;
        }

        IERC20 collateral = IERC20(bond.collateralToken());
        SafeERC20.safeTransferFrom(collateral, msg.sender, address(this), amount);

        return _borrow(amount, bond, collateral, currency, sales, minOutput);
    }

    /**
     * @dev Internal function to borrow a given currency from a given collateral
     * @param amount The amount of the collateral to deposit
     * @param bond The bond to deposit with
     * @param currency The currency to borrow
     * @param sales The amount of each tranche to sell for the currency.
     *  If MAX_UNT256, then sell full balance of the token
     * @param minOutput The minimum amount of currency that should be recived, else reverts
     */
    function _borrow(
        uint256 amount,
        IBondController bond,
        IERC20 collateral,
        IERC20 currency,
        uint256[] memory sales,
        uint256 minOutput
    ) internal returns (uint256 amountOut) {
        require(address(collateral) != address(currency), "LoanRouter: Invalid currency");

        SafeERC20.safeIncreaseAllowance(collateral, address(bond), amount);
        bond.deposit(amount);

        uint256 trancheCount = bond.trancheCount();
        require(trancheCount == sales.length, "LoanRouter: Invalid sales");
        ITranche tranche;
        for (uint256 i = 0; i < trancheCount; i++) {
            (tranche, ) = bond.tranches(i);
            uint256 sale = sales[i];
            uint256 trancheBalance = tranche.balanceOf(address(this));

            if (sale == MAX_UINT256) {
                sale = trancheBalance;
            } else if (sale == 0) {
                SafeERC20.safeTransfer(tranche, msg.sender, trancheBalance);
                continue;
            } else {
                // transfer any excess to the caller
                SafeERC20.safeTransfer(tranche, msg.sender, trancheBalance - sale);
            }

            _swap(address(tranche), address(currency), sale);
        }

        uint256 balance = currency.balanceOf(address(this));
        require(balance >= minOutput, "LoanRouter: Insufficient output");
        SafeERC20.safeTransfer(currency, msg.sender, balance);
        return balance;
    }

    /**
     * @dev Virtual function to define the swapping mechanism for a loan router
     * @param input The ERC20 token to input into the swap
     * @param output The ERC20 token to get out from the swap
     * @param amount The amount of input to put into the swap
     */
    function _swap(
        address input,
        address output,
        uint256 amount
    ) internal virtual;
}
