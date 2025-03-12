// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Asset.sol";

abstract contract Loan {
    using SafeMath for uint256;

    struct CreditLine {
        uint256 lockedAsset;
        address borrower;
        uint256 maturity;
        uint256 amount;
        uint256 debt;
        bool isClosed;
    }

    event CreditLineOpened(uint256 indexed loanId, uint256 indexed tokenId, address borrower, uint256 amount, uint256 maturity);
    event CreditLineClosed(uint256 indexed loanId);

    mapping(uint256 => CreditLine) public creditLines; // map (loanId => CreditLine)
    mapping(uint256 => uint256[]) creditLinesMap; // map (tokenId => [loanId, loanId, ...])
    mapping(uint256 => bool) public lockedAssetsIds; // map (tokenId => isLocked)
    uint256 loansIds;

    function createCreditLineInternal(address nftAddress, address borrower, uint256 tokenId) internal returns (uint256) {
        Asset nftFactory = Asset(nftAddress);

        require(nftFactory.ownerOf(tokenId) == address(this), "loan: Pool should be owner of the token");
        require(nftFactory.getRedeemStatus(tokenId) == false, "loan: Asset already redeemed");
        require(lockedAssetsIds[tokenId] == false, "loan: Asset is already used");

        uint256 nftMaturity = nftFactory.getTokenMaturity(tokenId);
        require(nftMaturity >= block.timestamp, "loan: Maturity date expired");

        uint256 creditLineValue = _calculateLoanAmount(nftFactory, tokenId);
        loansIds++;

        lockedAssetsIds[tokenId] = true;
        creditLinesMap[tokenId].push(loansIds);
        creditLines[loansIds] = CreditLine(
            tokenId,
            borrower,
            nftMaturity,
            creditLineValue,
            0,
            false
        );
        emit CreditLineOpened(loansIds, tokenId, borrower, creditLineValue, nftMaturity);
        return loansIds;
    }

    function _calculateLoanAmount(Asset nftFactory, uint256 tokenId) internal view returns (uint256) {
        uint256 nftValue = nftFactory.getTokenValue(tokenId);
        string memory nftRating = nftFactory.getTokenRating(tokenId);
        uint256 advanceRate = nftFactory.getRiskAdvanceRate(nftRating);

        return nftValue * advanceRate / 100;
    }

    function closeCreditLineInternal(uint256 loanId) internal returns (bool) {
        CreditLine storage creditLine = creditLines[loanId];

        require(creditLine.debt == 0, "Debt should be 0");
        require(creditLine.isClosed == false, "Credit line is already closed");

        lockedAssetsIds[creditLine.lockedAsset] = false;
        creditLine.isClosed = true;
        emit CreditLineClosed(loanId);
        return true;
    }

    function borrowInternal(uint256 loanId, address borrower, uint256 amount) internal returns (bool) {
        CreditLine storage creditLine = creditLines[loanId];

        require(borrower == creditLine.borrower, "Borrower should be the same");

        creditLine.debt = creditLine.debt.add(amount);
        return true;
    }

    function repayInternal(uint256 loanId, address borrower, uint256 amount) internal returns (bool) {
        CreditLine storage creditLine = creditLines[loanId];

        require(borrower == creditLine.borrower, "Borrower should be the same");
        require(creditLine.debt >= amount, "Debt should be greater than amount");

        creditLine.debt = creditLine.debt.sub(amount);
        return true;
    }
}