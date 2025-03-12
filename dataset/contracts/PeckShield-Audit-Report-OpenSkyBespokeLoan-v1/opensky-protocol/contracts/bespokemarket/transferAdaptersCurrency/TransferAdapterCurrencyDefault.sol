// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import '../interfaces/IOpenSkyBespokeSettings.sol';
import '../interfaces/ITransferAdapterCurrency.sol';

contract TransferAdapterCurrencyDefault is Context, ITransferAdapterCurrency {
    using SafeERC20 for IERC20;

    IOpenSkyBespokeSettings public immutable BESPOKE_SETTINGS;

    constructor(address bespokeSettings_) {
        BESPOKE_SETTINGS = IOpenSkyBespokeSettings(bespokeSettings_);
    }

    modifier onlyMarket() {
        require(_msgSender() == BESPOKE_SETTINGS.marketAddress(), 'BM_ACL_ONLY_BESPOKR_MARKET_CAN_CALL');
        _;
    }

    function transferOnLend(
        address asset,
        address from,
        address to,
        uint256 amount,
        BespokeTypes.Offer memory offerData
    ) external onlyMarket {
        // asset match rule
        require(offerData.lendAsset == asset, 'BM_TRANSFER_ON_LEND_ASSET_NOT_MATCH');
        require(offerData.currency == offerData.lendAsset, 'BM_TRANSFER_ON_LEND_PAIR_NOT_SUPPORTED');

        IERC20(asset).safeTransferFrom(from, to, amount);
    }

    function transferOnRepay(
        address asset,
        address from,
        address to,
        uint256 amount,
        BespokeTypes.LoanData memory loanData
    ) external onlyMarket {
        // asset match rule
        require(loanData.lendAsset == asset, 'BM_TRANSFER_ADAPTER_ASSET_NOT_MATCH');
        require(loanData.currency == loanData.lendAsset, 'BM_TRANSFER_ADAPTER_PAIR_NOT_SUPPORTED');

        IERC20(asset).safeTransferFrom(from, to, amount);
    }
}
