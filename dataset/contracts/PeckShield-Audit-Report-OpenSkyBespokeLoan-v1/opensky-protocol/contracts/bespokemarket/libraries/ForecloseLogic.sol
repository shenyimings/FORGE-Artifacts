// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '../interfaces/IOpenSkyBespokeSettings.sol';
import '../interfaces/ITransferAdapterNFT.sol';

import './BespokeTypes.sol';
import './BespokeLogic.sol';

library ForecloseLogic {
    event Foreclose(uint256 indexed loanId, address indexed operator, address indexed receiver);

    function foreclose(
        mapping(uint256 => BespokeTypes.LoanData) storage _loans,
        uint256 loanId,
        IOpenSkyBespokeSettings BESPOKE_SETTINGS
    ) public {
        BespokeTypes.LoanData memory loanData = BespokeLogic.getLoanDataWithStatus(_loans[loanId]);
        require(loanData.status == BespokeTypes.LoanStatus.LIQUIDATABLE, 'BM_FORECLOSE_STATUS_ERROR');

        (, address lender) = BespokeLogic.getLoanParties(BESPOKE_SETTINGS, loanId);
        
        ITransferAdapterNFT(loanData.nftManager).transferCollateralOutOnForeclose(
            loanData.tokenAddress,
            lender,
            loanData.tokenId,
            loanData.tokenAmount
        );

        BespokeLogic.burnLoanNft(_loans, loanId, BESPOKE_SETTINGS);

        emit Foreclose(loanId, msg.sender, lender);
    }
}
