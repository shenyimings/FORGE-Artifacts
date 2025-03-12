// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "contracts/interfaces/INoteAdapter.sol";

import "./TestLendingPlatform.sol";

/**
 * @title Test Note Adapter
 */
contract TestNoteAdapter is INoteAdapter {
    /**************************************************************************/
    /* Properties */
    /**************************************************************************/

    TestLendingPlatform private immutable _lendingPlatform;

    /**************************************************************************/
    /* Constructor */
    /**************************************************************************/

    /**
     * @notice TestNoteAdapter constructor
     * @param testLendingPlatform Test lending platform contract
     */
    constructor(TestLendingPlatform testLendingPlatform) {
        _lendingPlatform = testLendingPlatform;
    }

    /**************************************************************************/
    /* Implementation */
    /**************************************************************************/

    /**
     * @inheritdoc INoteAdapter
     */
    function noteToken() external view returns (IERC721) {
        return IERC721(_lendingPlatform.noteToken());
    }

    /**
     * @inheritdoc INoteAdapter
     */
    function isSupported(uint256 noteTokenId, address currencyToken) external view returns (bool) {
        /* All collateral tokens supported, so just check the note exists and
         * the currency token matches */
        return
            _lendingPlatform.noteToken().exists(noteTokenId) &&
            address(_lendingPlatform.currencyToken()) == currencyToken;
    }

    /**
     * @inheritdoc INoteAdapter
     */
    function getLoanInfo(uint256 noteTokenId) external view returns (LoanInfo memory) {
        /* Get loan from lending platform */
        (
            TestLendingPlatform.LoanStatus status,
            address borrower,
            uint256 principal,
            uint256 repayment,
            uint64 startTime,
            uint32 duration,
            address collateralToken,
            uint256 collateralTokenId
        ) = _lendingPlatform.loans(noteTokenId);

        /* Check loan exists */
        require(status != TestLendingPlatform.LoanStatus.Unknown, "Unknown loan");

        /* Arrange into LoanInfo structure */
        LoanInfo memory loanInfo;
        loanInfo.loanId = noteTokenId;
        loanInfo.borrower = borrower;
        loanInfo.principal = principal;
        loanInfo.repayment = repayment;
        loanInfo.maturity = startTime + duration;
        loanInfo.duration = duration;
        loanInfo.currencyToken = address(_lendingPlatform.currencyToken());
        loanInfo.collateralToken = collateralToken;
        loanInfo.collateralTokenId = collateralTokenId;

        return loanInfo;
    }

    /**
     * @inheritdoc INoteAdapter
     */
    function getLiquidateCalldata(uint256 loanId) external view returns (address, bytes memory) {
        return (address(_lendingPlatform), abi.encodeWithSignature("liquidate(uint256)", loanId));
    }

    /**
     * @inheritdoc INoteAdapter
     */
    function getUnwrapCalldata(uint256 loanId) external view returns (address, bytes memory) {
        /* Get collateral token info from lending platform */
        (, , , , , , address collateralToken, uint256 collateralTokenId) = _lendingPlatform.loans(loanId);

        /* Dummy operation to test unwrap call in Vault withdrawCollateral() */
        if (IERC721(collateralToken).ownerOf(collateralTokenId) == msg.sender) {
            return (
                collateralToken,
                abi.encodeWithSignature(
                    "transferFrom(address,address,uint256)",
                    msg.sender,
                    msg.sender,
                    collateralTokenId
                )
            );
        } else {
            return (address(0), "");
        }
    }

    /**
     * @inheritdoc INoteAdapter
     */
    function isRepaid(uint256 loanId) external view returns (bool) {
        /* Get loan status from lending platform */
        (TestLendingPlatform.LoanStatus status, , , , , , , ) = _lendingPlatform.loans(loanId);
        return status == TestLendingPlatform.LoanStatus.Repaid;
    }

    /**
     * @inheritdoc INoteAdapter
     */
    function isLiquidated(uint256 loanId) external view returns (bool) {
        /* Get loan status from lending platform */
        (TestLendingPlatform.LoanStatus status, , , , , , , ) = _lendingPlatform.loans(loanId);
        return status == TestLendingPlatform.LoanStatus.Liquidated;
    }

    /**
     * @inheritdoc INoteAdapter
     */
    function isExpired(uint256 loanId) external view returns (bool) {
        /* Get loan maturity from lending platform */
        (, , , , uint64 startTime, uint32 duration, , ) = _lendingPlatform.loans(loanId);
        return block.timestamp > startTime + duration;
    }
}
