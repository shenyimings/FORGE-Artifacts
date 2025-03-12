// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import '../../interfaces/IOpenSkySettings.sol';

import '../interfaces/IOpenSkyBespokeSettings.sol';
import '../interfaces/ITransferAdapterCurrency.sol';
import '../interfaces/ITransferAdapterNFT.sol';

import './BespokeTypes.sol';
import './BespokeLogic.sol';

library RepayLogic {
    using SafeERC20 for IERC20;

    event Repay(uint256 indexed loanId, address indexed operator, address indexed receiver);

    function repay(
        mapping(uint256 => BespokeTypes.LoanData) storage _loans,
        uint256 loanId,
        IOpenSkyBespokeSettings BESPOKE_SETTINGS,
        IOpenSkySettings SETTINGS
    ) public {
        BespokeTypes.LoanData memory loanData = BespokeLogic.getLoanDataWithStatus(_loans[loanId]);
        require(
            loanData.status == BespokeTypes.LoanStatus.BORROWING || loanData.status == BespokeTypes.LoanStatus.OVERDUE,
            'BM_REPAY_STATUS_ERROR'
        );

        (address borrower, address lender) = BespokeLogic.getLoanParties(BESPOKE_SETTINGS, loanId);

        (uint256 repayTotal, uint256 lenderAmount, uint256 protocolFee) = BespokeLogic
            .calculateRepayAmountAndProtocolFee(loanData);
        address currencyTransferAdapter = BESPOKE_SETTINGS.getCurrencyTransferAdapter(loanData.lendAsset);

        IERC20(loanData.currency).safeTransferFrom(msg.sender, address(this), lenderAmount);
        IERC20(loanData.currency).approve(currencyTransferAdapter, lenderAmount);
        ITransferAdapterCurrency(currencyTransferAdapter).transferOnRepay(
            loanData.lendAsset,
            address(this),
            lender,
            lenderAmount,
            loanData
        );

        // protocol income
        if (protocolFee > 0) {
            IERC20(loanData.currency).safeTransferFrom(msg.sender, SETTINGS.daoVaultAddress(), protocolFee);
        }

        ITransferAdapterNFT(loanData.nftManager).transferCollateralOut(
            loanData.tokenAddress,
            borrower,
            loanData.tokenId,
            loanData.tokenAmount
        );

        BespokeLogic.burnLoanNft(_loans, loanId, BESPOKE_SETTINGS);

        emit Repay(loanId, msg.sender, borrower);
    }
}
