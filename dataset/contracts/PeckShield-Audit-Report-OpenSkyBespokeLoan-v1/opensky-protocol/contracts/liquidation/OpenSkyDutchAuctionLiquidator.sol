// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../interfaces/IOpenSkySettings.sol";
import "../interfaces/IOpenSkyLoan.sol";
import "../interfaces/IOpenSkyPool.sol";
import "../interfaces/IACLManager.sol";
import "../interfaces/IOpenSkyDutchAuctionPriceOracle.sol";
import "../dependencies/weth/IWETH.sol";
import "../libraries/math/WadRayMath.sol";
import "../libraries/types/DataTypes.sol";

contract OpenSkyDutchAuctionLiquidator is ERC721Holder {
    using SafeERC20 for IERC20;
    using WadRayMath for uint128;

    event Liquidate(address indexed sender, uint256 indexed loanId, uint256 price, address nftAddress, uint256 tokenId);

    IOpenSkySettings public immutable SETTINGS;
    IWETH public immutable WETH;
    IOpenSkyDutchAuctionPriceOracle public priceOracle;

    modifier onlyGovernance() {
        IACLManager ACLManager = IACLManager(SETTINGS.ACLManagerAddress());
        require(ACLManager.isGovernance(msg.sender), "ONLY_GOVERNANCE");
        _;
    }

    constructor(address settings, address weth, address _priceOracle) {
        SETTINGS = IOpenSkySettings(settings);
        WETH = IWETH(weth);
        priceOracle = IOpenSkyDutchAuctionPriceOracle(_priceOracle);
    }

    function setPriceOracle(address _priceOracle) external onlyGovernance {
        priceOracle = IOpenSkyDutchAuctionPriceOracle(_priceOracle);
    }

    function liquidateETH(uint256 loanId) external payable {
        IOpenSkyLoan loanNFT = IOpenSkyLoan(SETTINGS.loanAddress());

        uint256 price = getPrice(loanId);
        uint256 borrowBalance = loanNFT.getBorrowBalance(loanId);
        require(msg.value >= price, "INSUFFICIENT_AMOUNT");
        require(price >= borrowBalance, "PRICE_ERROR");

        DataTypes.LoanData memory loanData = loanNFT.getLoanData(loanId);

        // start liquidation
        IOpenSkyPool(SETTINGS.poolAddress()).startLiquidation(loanId);
        
        WETH.deposit{value: borrowBalance}();

        // end liquidation
        WETH.approve(SETTINGS.poolAddress(), borrowBalance);
        IOpenSkyPool(SETTINGS.poolAddress()).endLiquidation(loanId, borrowBalance);

        IERC721(loanData.nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            loanData.tokenId
        );

        if (price > borrowBalance) {
            _safeTransferETH(SETTINGS.daoVaultAddress(), price - borrowBalance);
        }

        if (msg.value > price) {
            _safeTransferETH(msg.sender, msg.value - price);
        }
    }

    function liquidate(uint256 loanId) public {
        IOpenSkyLoan loanNFT = IOpenSkyLoan(SETTINGS.loanAddress());
        uint256 price = getPrice(loanId);
        uint256 borrowBalance = loanNFT.getBorrowBalance(loanId);
        require(price > borrowBalance, "PRICE_ERROR");

        // start liquidation
        IOpenSkyPool(SETTINGS.poolAddress()).startLiquidation(loanId);

        DataTypes.LoanData memory loanData = loanNFT.getLoanData(loanId);
        DataTypes.ReserveData memory reserveData = IOpenSkyPool(SETTINGS.poolAddress()).getReserveData(loanData.reserveId);

        IERC20(reserveData.underlyingAsset).safeTransferFrom(msg.sender, address(this), price);

        // end liquidation
        IERC20(reserveData.underlyingAsset).safeApprove(SETTINGS.poolAddress(), borrowBalance);
        IOpenSkyPool(SETTINGS.poolAddress()).endLiquidation(loanId, borrowBalance);

        // transfer rewards to treasury
        IERC20(reserveData.underlyingAsset).safeTransfer(SETTINGS.treasuryAddress(), price - borrowBalance);

        IERC721(loanData.nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            loanData.tokenId
        );
        
        emit Liquidate(msg.sender, loanId, price, loanData.nftAddress, loanData.tokenId);
    }

    function getPrice(uint256 loanId) public view returns (uint256) {
        IOpenSkyLoan loanNFT = IOpenSkyLoan(SETTINGS.loanAddress());

        require(loanNFT.getStatus(loanId) == DataTypes.LoanStatus.LIQUIDATABLE, "LOAN_STATUS_ERROR");

        DataTypes.LoanData memory loanData = loanNFT.getLoanData(loanId);
        uint256 borrowBalance = loanNFT.getBorrowBalance(loanId);

        return priceOracle.getPrice(borrowBalance, loanData.liquidatableTime);
    }

    function _safeTransferETH(address recipient, uint256 amount) internal {
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "ETH_TRANSFER_FAILED");
    }
}
