// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import '../../interfaces/IOpenSkySettings.sol';
import '../../interfaces/IOpenSkyPool.sol';

import '../interfaces/IOpenSkyBespokeSettings.sol';
import '../interfaces/ITransferAdapterCurrency.sol';

contract TransferAdapterOToken is Context, Ownable, ITransferAdapterCurrency {
    using SafeERC20 for IERC20;

    // oToken address => reserveId
    mapping(address => uint256) public getReserveId;

    IOpenSkySettings public immutable SETTINGS;
    IOpenSkyBespokeSettings public immutable BESPOKE_SETTINGS;

    event SetOTokenToReserveIdMap(address oToken, uint256 reserveId);
    event UnsetOTokenToReserveIdMap(address oToken);

    constructor(address settingsAddress_, address bespokeSettings_) {
        SETTINGS = IOpenSkySettings(settingsAddress_);
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
        require(offerData.lendAsset == asset, 'BM_TRANSFER_ADAPTER_OTOKEN_ASSET_NOT_MATCH');

        uint256 reserveId = getReserveId[asset];
        require(reserveId > 0, 'BM_TRANSFER_ADAPTER_OTOKEN_RESERVEID_NOT_CONFIGURED');
        DataTypes.ReserveData memory reserve = IOpenSkyPool(SETTINGS.poolAddress()).getReserveData(reserveId);

        // validate oToken=>reserveId
        require(asset == reserve.oTokenAddress, 'BM_TRANSFER_ADAPTER_OTOKEN_OTOKEN_ASSET_NOT_MATCH');
        // lend underlyingAsset/currency using oToken
        require(offerData.currency == reserve.underlyingAsset, 'BM_TRANSFER_ADAPTER_OTOKEN_UNDERLYING_NOT_MATCH');

        uint256 oTokenBalance = IERC20(asset).balanceOf(from);
        uint256 availableLiquidity = IOpenSkyPool(SETTINGS.poolAddress()).getAvailableLiquidity(reserveId);
        require(oTokenBalance >= amount, 'BM_TRANSFER_ADAPTER_OTOKEN_NOT_ENOUGH');
        require(availableLiquidity >= amount, 'BM_TRANSFER_ADAPTER_OTOKEN_POOL_LIQUIDITY_NOT_ENOUGH');

        IERC20(reserve.oTokenAddress).safeTransferFrom(from, address(this), amount);
        // withdraw underlying to borrower
        IOpenSkyPool(SETTINGS.poolAddress()).withdraw(reserveId, amount, to);
    }

    //@dev only accept underlying to repay
    function transferOnRepay(
        address asset, // should be oToken
        address from,
        address to,
        uint256 amount,
        BespokeTypes.LoanData memory loanData
    ) external onlyMarket {
        require(loanData.lendAsset == asset, 'BM_TRANSFER_ADAPTER_OTOKEN_ASSET_NOT_MATCH');

        uint256 reserveId = getReserveId[asset];
        require(reserveId > 0, 'BM_TRANSFER_ADAPTER_OTOKEN_RESERVEID_NOT_CONFIGURED');

        // oToken balance
        DataTypes.ReserveData memory reserve = IOpenSkyPool(SETTINGS.poolAddress()).getReserveData(reserveId);

        // validate oToken=>reserveId
        require(asset == reserve.oTokenAddress, 'BM_TRANSFER_ADAPTER_OTOKEN_ASSET_NOT_MATCH');
        // lend underlyingAsset/currency using oToken
        require(loanData.currency == reserve.underlyingAsset, 'BM_TRANSFER_ADAPTER_OTOKEN_UNDERLYING_NOT_MATCH');

        // convert to lend asset
        if (loanData.autoConvertWhenRepay) {
            IERC20(reserve.underlyingAsset).safeTransferFrom(from, address(this), amount);
            IERC20(reserve.underlyingAsset).approve(SETTINGS.poolAddress(), amount);
            IOpenSkyPool(SETTINGS.poolAddress()).deposit(reserveId, amount, to, 0);
        } else {
            IERC20(reserve.underlyingAsset).safeTransferFrom(from, to, amount);
        }
    }

    // reserveId should be configured for every oToken added to currency whitelist
    function setOTokenToReserveIdMap(address oToken, uint256 reserveId) external onlyOwner {
        require(
            IOpenSkyPool(SETTINGS.poolAddress()).getReserveData(reserveId).oTokenAddress == oToken,
            'BM_TRANSFER_ADAPTER_OTOKEN_SET_RESERVE_NOT_MATCH'
        );
        getReserveId[oToken] = reserveId;
        emit SetOTokenToReserveIdMap(oToken, reserveId);
    }

    function unsetOTokenToReserveIdMap(address oToken) external onlyOwner {
        getReserveId[oToken] = 0;
        emit UnsetOTokenToReserveIdMap(oToken);
    }
}
