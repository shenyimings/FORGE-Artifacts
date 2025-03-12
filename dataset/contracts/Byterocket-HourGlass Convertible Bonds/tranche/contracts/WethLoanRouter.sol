pragma solidity ^0.8.3;

import "./interfaces/IWethLoanRouter.sol";
import "./interfaces/ILoanRouter.sol";
import "./interfaces/IBondController.sol";
import "./interfaces/ITranche.sol";
import "./interfaces/IButtonWrapper.sol";
import "./interfaces/IWETH9.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import "@rari-capital/solmate/src/tokens/ERC20.sol";

/**
 * @dev Weth Loan Router built on top of a LoanRouter of your choosing
 * to allow loans to be created with raw ETH instead of WETH
 */
contract WethLoanRouter is IWethLoanRouter {
    ILoanRouter public immutable loanRouter;
    IWETH9 public immutable weth;

    /**
     * @dev Constructor for setting underlying loanRouter and weth contracts
     * @param _loanRouter The underlying loanRouter that does all the wrapping and trading
     * @param _weth The WETH contract to wrap ETH in
     */
    constructor(ILoanRouter _loanRouter, IWETH9 _weth) {
        loanRouter = _loanRouter;
        weth = _weth;
    }

    /**
     * @inheritdoc IWethLoanRouter
     */
    function wrapAndBorrow(
        IBondController bond,
        IERC20 currency,
        uint256[] memory sales,
        uint256 minOutput
    ) external payable override returns (uint256 amountOut) {
        uint256 wethBalance = _wethWrapAndApprove();
        amountOut = loanRouter.wrapAndBorrow(wethBalance, bond, currency, sales, minOutput);
        require(amountOut >= minOutput, "WethLoanRouter: Insufficient output");
        _distributeLoanOutput(amountOut, bond, currency);
        return amountOut;
    }

    /**
     * @inheritdoc IWethLoanRouter
     */
    function wrapAndBorrowMax(
        IBondController bond,
        IERC20 currency,
        uint256 minOutput
    ) external payable override returns (uint256 amountOut) {
        uint256 wethBalance = _wethWrapAndApprove();
        amountOut = loanRouter.wrapAndBorrowMax(wethBalance, bond, currency, minOutput);
        require(amountOut >= minOutput, "WethLoanRouter: Insufficient output");
        _distributeLoanOutput(amountOut, bond, currency);
        return amountOut;
    }

    /**
     * @dev Wraps the ETH that was transferred to this contract and then approves loanRouter for entire amount
     * @dev No need to check that bond's collateral has WETH as underlying since deposit will fail otherwise
     * @return WETH balance that was wrapped. Equal to loanRouter allowance for WETH.
     */
    function _wethWrapAndApprove() internal returns (uint256) {
        // Confirm that ETH was sent
        uint256 value = msg.value;
        require(value > 0, "ButtonTokenWethRouter: No ETH supplied");

        // Wrapping ETH into weth
        weth.deposit{ value: value }();

        // Approve loanRouter to take weth
        uint256 wethBalance = weth.balanceOf(address(this));
        weth.approve(address(loanRouter), wethBalance);
        return wethBalance;
    }

    /**
     * @dev Distributes tranche balances and borrowed amounts to end-user
     * @param amountOut The output amount that is being borrowed
     * @param bond The bond that is being borrowed from
     * @param currency The asset being borrowed
     */
    function _distributeLoanOutput(
        uint256 amountOut,
        IBondController bond,
        IERC20 currency
    ) internal {
        // Send loan currenncy out from this contract to msg.sender
        SafeTransferLib.safeTransfer(ERC20(address(currency)), msg.sender, amountOut);

        // Send out the tranche tokens from this contract to the msg.sender
        ITranche tranche;
        for (uint256 i = 0; i < bond.trancheCount(); i++) {
            (tranche, ) = bond.tranches(i);
            SafeTransferLib.safeTransfer(ERC20(address(tranche)), msg.sender, tranche.balanceOf(address(this)));
        }
    }
}
