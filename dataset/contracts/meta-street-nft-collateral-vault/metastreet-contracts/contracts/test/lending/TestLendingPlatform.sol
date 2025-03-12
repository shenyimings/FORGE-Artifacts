// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "contracts/interfaces/ILoanReceiver.sol";

import "./TestNoteToken.sol";

/**
 * @title Test Lending Platform
 */
contract TestLendingPlatform is Ownable, ERC721Holder, ERC165 {
    using SafeERC20 for IERC20;

    /**************************************************************************/
    /* Events */
    /**************************************************************************/

    /**
     * @notice Emitted when a loan is created
     * @param loanId Loan ID
     * @param borrower Borrower
     * @param lender Lender
     */
    event LoanCreated(uint256 loanId, address borrower, address lender);

    /**
     * @notice Emitted when a loan is repaid
     * @param loanId Loan ID
     */
    event LoanRepaid(uint256 loanId);

    /**
     * @notice Emitted when a loan is liquidated
     * @param loanId Loan ID
     */
    event LoanLiquidated(uint256 loanId);

    /**************************************************************************/
    /* State */
    /**************************************************************************/

    /**
     * @notice Loan status
     */
    enum LoanStatus {
        Unknown,
        Active,
        Repaid,
        Liquidated
    }

    /**
     * @notice Loan terms
     * @param status Loan status
     * @param borrower Borrower
     * @param principal Principal amount
     * @param repayment Repayment amount
     * @param startTime Start timestamp
     * @param duration Duration in seconds
     * @param collateralToken Collateral token contract
     * @param collateralTokenId Collateral token ID
     */
    struct LoanTerms {
        LoanStatus status;
        address borrower;
        uint256 principal;
        uint256 repayment;
        uint64 startTime;
        uint32 duration;
        address collateralToken;
        uint256 collateralTokenId;
    }

    /**************************************************************************/
    /* Properties and State */
    /**************************************************************************/

    /**
     * @dev Currency token
     */
    IERC20 public immutable currencyToken;

    /**
     * @dev Promissory note token
     */
    TestNoteToken public immutable noteToken;

    /**
     * @dev Mapping of loan ID to loan terms
     */
    mapping(uint256 => LoanTerms) public loans;

    /**
     * @dev Mapping of loan ID to complete boolean
     */
    mapping(uint256 => bool) public loansComplete;

    /**
     * @dev Loan ID counter
     */
    uint256 private _loanId;

    /**************************************************************************/
    /* Constructor */
    /**************************************************************************/

    /**
     * @notice TestLendingPlatform constructor
     * @param currencyToken_ Currency token
     */
    constructor(IERC20 currencyToken_) {
        currencyToken = currencyToken_;
        noteToken = new TestNoteToken();
    }

    /**************************************************************************/
    /* Primary API */
    /**************************************************************************/

    /**
     * @notice Create a new loan
     *
     * Emits a {LoanCreated} event.
     *
     * @param borrower Borrower
     * @param lender Lender
     * @param collateralToken Collateral token contract
     * @param collateralTokenId Collateral token ID
     * @param principal Principal amount
     * @param repayment Repayment amount
     * @param duration Duration in seconds
     */
    function lend(
        address borrower,
        address lender,
        IERC721 collateralToken,
        uint256 collateralTokenId,
        uint256 principal,
        uint256 repayment,
        uint32 duration
    ) external {
        require(repayment >= principal, "Repayment less than principal");

        uint256 loanId = _loanId++;

        LoanTerms storage loan = loans[loanId];
        loan.status = LoanStatus.Active;
        loan.borrower = borrower;
        loan.principal = principal;
        loan.repayment = repayment;
        loan.startTime = uint64(block.timestamp);
        loan.duration = duration;
        loan.collateralToken = address(collateralToken);
        loan.collateralTokenId = collateralTokenId;

        collateralToken.safeTransferFrom(borrower, address(this), collateralTokenId);
        currencyToken.safeTransferFrom(lender, borrower, principal);
        noteToken.mint(lender, loanId);

        emit LoanCreated(loanId, borrower, lender);
    }

    /**
     * @notice Repay a loan
     *
     * Emits a {LoanRepaid} event.
     *
     * @param loanId Loan ID
     * @param callback Callback to loan holder
     */
    function repay(uint256 loanId, bool callback) external {
        LoanTerms storage loan = loans[loanId];

        require(loan.borrower != address(0x0), "Unknown loan");
        require(!loansComplete[loanId], "Loan already complete");
        require(loan.borrower == msg.sender, "Invalid caller");

        loan.status = LoanStatus.Repaid;
        loansComplete[loanId] = true;

        address noteOwner = noteToken.ownerOf(loanId);

        currencyToken.safeTransferFrom(loan.borrower, noteOwner, loan.repayment);
        IERC721(loan.collateralToken).safeTransferFrom(address(this), loan.borrower, loan.collateralTokenId);
        noteToken.burn(loanId);

        if (callback && ERC165Checker.supportsInterface(noteOwner, type(ILoanReceiver).interfaceId))
            ILoanReceiver(noteOwner).onLoanRepaid(address(noteToken), loanId);

        emit LoanRepaid(loanId);
    }

    /**
     * @notice Liquidate a loan
     *
     * Emits a {LoanLiquidated} event.
     *
     * @param loanId Loan ID
     */
    function liquidate(uint256 loanId) external {
        LoanTerms storage loan = loans[loanId];

        require(loan.borrower != address(0x0), "Unknown loan");
        require(!loansComplete[loanId], "Loan already complete");
        require(block.timestamp > loan.startTime + loan.duration, "Loan not expired");
        require(noteToken.ownerOf(loanId) == msg.sender, "Invalid caller");

        loan.status = LoanStatus.Liquidated;
        loansComplete[loanId] = true;

        IERC721(loan.collateralToken).safeTransferFrom(
            address(this),
            noteToken.ownerOf(loanId),
            loan.collateralTokenId
        );
        noteToken.burn(loanId);

        emit LoanLiquidated(loanId);
    }

    /******************************************************/
    /* ERC165 interface */
    /******************************************************/

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId || super.supportsInterface(interfaceId);
    }
}
