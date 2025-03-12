pragma solidity ^0.8.3;

import "./interfaces/ILoanRouter.sol";
import "./interfaces/IBondController.sol";
import "./interfaces/ITranche.sol";
import "./interfaces/IButtonWrapper.sol";
import "./interfaces/IWAMPL.sol";
import "./interfaces/IWamplLoanRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import "@rari-capital/solmate/src/tokens/ERC20.sol";

/**
 * @dev Wampl Loan Router built on top of a LoanRouter of your choosing
 * to allow loans to be created with raw ampl instead of WAMPL
 */
contract WamplLoanRouter is IWamplLoanRouter {
    ILoanRouter public immutable loanRouter;
    IWAMPL public immutable wampl;
    ERC20 public immutable ampl;

    /**
     * @dev Constructor for setting underlying loanRouter and wampl contracts
     * @param _loanRouter The underlying loanRouter that does all the wrapping and trading
     * @param _wampl The WAMPL contract to wrap AMPL in
     */
    constructor(ILoanRouter _loanRouter, IWAMPL _wampl) {
        loanRouter = _loanRouter;
        wampl = _wampl;
        // Accessing AMPL contract from WAMPL contract
        ampl = ERC20(_wampl.underlying());
    }

    /**
     * @inheritdoc IWamplLoanRouter
     */
    function wrapAndBorrow(
        uint256 amplAmount,
        IBondController bond,
        IERC20 currency,
        uint256[] memory sales,
        uint256 minOutput
    ) external override returns (uint256 amountOut) {
        uint256 wamplBalance = _wamplWrapAndApprove(amplAmount);
        amountOut = loanRouter.wrapAndBorrow(wamplBalance, bond, currency, sales, minOutput);
        require(amountOut >= minOutput, "WamplLoanRouter: Insufficient output");
        _distributeLoanOutput(amountOut, bond, currency);
        return amountOut;
    }

    /**
     * @inheritdoc IWamplLoanRouter
     */
    function wrapAndBorrowMax(
        uint256 amplAmount,
        IBondController bond,
        IERC20 currency,
        uint256 minOutput
    ) external override returns (uint256 amountOut) {
        uint256 wamplBalance = _wamplWrapAndApprove(amplAmount);
        amountOut = loanRouter.wrapAndBorrowMax(wamplBalance, bond, currency, minOutput);
        require(amountOut >= minOutput, "WamplLoanRouter: Insufficient output");
        _distributeLoanOutput(amountOut, bond, currency);
        return amountOut;
    }

    /**
     * @dev Wraps the AMPL that was transferred to this contract and then approves loanRouter for entire amount
     * @dev No need to check that bond's collateral has WAMPL as underlying since deposit will fail otherwise
     * @return WAMPL balance that was wrapped. Equal to loanRouter allowance for WAMPL.
     */
    function _wamplWrapAndApprove(uint256 amplAmount) internal returns (uint256) {
        // Confirm that AMPL was sent
        require(amplAmount > 0, "WamplLoanRouter: No AMPL supplied");

        // Transferring AMPL to contract
        SafeTransferLib.safeTransferFrom(ampl, msg.sender, address(this), amplAmount);

        // Wrapping contract's balance of AMPL into WAMPL
        ampl.approve(address(wampl), amplAmount);
        uint256 wamplAmount = wampl.deposit(amplAmount);

        // Approve loanRouter to take wampl
        wampl.approve(address(loanRouter), wamplAmount);
        return wamplAmount;
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
