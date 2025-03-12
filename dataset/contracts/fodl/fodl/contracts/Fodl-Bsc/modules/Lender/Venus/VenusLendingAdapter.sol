// SPDX-License-Identifier: MIT

pragma solidity 0.6;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import { ILendingPlatformBSC } from '../LendingDispatcherBSC.sol';

import '../../../../Fodl/core/interfaces/ICTokenProvider.sol';
import '../../../../Fodl/modules/Lender/ILendingPlatform.sol';

import '../../../../Libs/IWETH.sol';
import '../../../../Libs/Uint2Str.sol';

import './IVenus.sol';

contract VenusLendingAdapter is ILendingPlatform, ILendingPlatformBSC, Uint2Str {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IWETH public immutable WBNB; //0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    ICTokenProvider public immutable vTokenProvider;

    uint256 private constant BLOCKS_PER_YEAR = 365 * 24 * 60 * 20; // 3sec block on bsc
    uint256 private constant MANTISSA = 1e18;

    constructor(address wbnbAddress, address vTokenProviderAddress) public {
        require(wbnbAddress != address(0), 'ICP0');
        require(vTokenProviderAddress != address(0), 'ICP0');
        WBNB = IWETH(wbnbAddress);
        vTokenProvider = ICTokenProvider(vTokenProviderAddress);
    }

    // Maps a token to its corresponding cToken
    function getVToken(address platform, address token) private view returns (address) {
        return vTokenProvider.getCToken(platform, token);
    }

    function buildErrorMessage(string memory message, uint256 code) private pure returns (string memory) {
        return string(abi.encodePacked(message, ': ', uint2str(code)));
    }

    function getCollateralUsageFactor(address platform) external override returns (uint256) {
        uint256 sumCollateral = 0;
        uint256 sumBorrows = 0;

        address priceOracle = IVComptroller(platform).oracle();

        // For each asset the account is in
        address[] memory assets = IVComptroller(platform).getAssetsIn(address(this));
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];

            uint256 borrowBalance = IVToken(asset).borrowBalanceCurrent(address(this));
            uint256 supplyBalance = IVToken(asset).balanceOfUnderlying(address(this));

            // Get collateral factor for this asset
            (, uint256 collateralFactor, ) = IVComptroller(platform).markets(asset);

            // Get the normalized price of the asset
            uint256 oraclePrice = IVenusPriceOracle(priceOracle).getUnderlyingPrice(asset);

            // the collateral value will be price * collateral balance * collateral factor. Since
            // both oracle price and collateral factor are scaled by 1e18, we need to undo this scaling
            sumCollateral = sumCollateral.add(oraclePrice.mul(collateralFactor).mul(supplyBalance) / MANTISSA**2);
            sumBorrows = sumBorrows.add(oraclePrice.mul(borrowBalance) / MANTISSA);
        }
        if (sumCollateral > 0) return sumBorrows.mul(MANTISSA) / sumCollateral;
        return 0;
    }

    function getCollateralFactorForAsset(address platform, address asset)
        external
        override
        returns (uint256 collateralFactor)
    {
        (, collateralFactor, ) = IVComptroller(platform).markets(getVToken(platform, asset));
    }

    /// @dev Venus returns reference prices with regard to USD scaled by 1e18. Decimals disparity is taken into account
    function getReferencePrice(address platform, address token) public override returns (uint256) {
        address vToken = getVToken(platform, token);
        return IVenusPriceOracle(IVComptroller(platform).oracle()).getUnderlyingPrice(vToken);
    }

    function getBorrowBalance(address platform, address token) external override returns (uint256 borrowBalance) {
        return IVToken(getVToken(platform, token)).borrowBalanceCurrent(address(this));
    }

    function getSupplyBalance(address platform, address token) external override returns (uint256 supplyBalance) {
        return IVToken(getVToken(platform, token)).balanceOfUnderlying(address(this));
    }

    function claimRewards(address platform) public override returns (address rewardsToken, uint256 rewardsAmount) {
        rewardsToken = IVComptroller(platform).getXVSAddress();
        rewardsAmount = IERC20(rewardsToken).balanceOf(address(this));

        IVComptroller(platform).claimVenus(address(this));

        rewardsAmount = IERC20(rewardsToken).balanceOf(address(this)).sub(rewardsAmount);
    }

    function enterMarkets(address platform, address[] calldata markets) external override {
        address[] memory vTokens = new address[](markets.length);
        for (uint256 i = 0; i < markets.length; i++) {
            vTokens[i] = getVToken(platform, markets[i]);
        }
        uint256[] memory results = IVComptroller(platform).enterMarkets(vTokens);
        for (uint256 i = 0; i < results.length; i++) {
            require(results[i] == 0, buildErrorMessage('Venus: enterMarkets', results[i]));
        }
    }

    function supply(
        address platform,
        address token,
        uint256 amount
    ) external override {
        address vToken = getVToken(platform, token);

        if (token == address(WBNB)) {
            WBNB.withdraw(amount);
            IVBNB(vToken).mint{ value: amount }();
            // reverts on error
        } else {
            IERC20(token).safeIncreaseAllowance(vToken, amount);
            uint256 result = IVToken(vToken).mint(amount);
            require(result == 0, buildErrorMessage('Venus: mint', result));
            // cant reproduce mint error in tests
        }
    }

    function borrow(
        address platform,
        address token,
        uint256 amount
    ) external override {
        address vToken = getVToken(platform, token);

        uint256 result = IVToken(vToken).borrow(amount);
        require(result == 0, buildErrorMessage('Venus: borrow', result));

        if (token == address(WBNB)) {
            WBNB.deposit{ value: amount }();
        }
    }

    function redeemSupply(
        address platform,
        address token,
        uint256 amount
    ) external override {
        address vToken = address(getVToken(platform, token));

        uint256 result = IVToken(vToken).redeemUnderlying(amount);
        require(result == 0, buildErrorMessage('Venus: redeem', result));

        if (token == address(WBNB)) {
            WBNB.deposit{ value: amount }();
        }
    }

    function repayBorrow(
        address platform,
        address token,
        uint256 amount
    ) external override {
        address vToken = address(getVToken(platform, token));

        if (token == address(WBNB)) {
            WBNB.withdraw(amount);
            IVBNB(vToken).repayBorrow{ value: amount }();
        } else {
            IERC20(token).safeIncreaseAllowance(vToken, amount);
            uint256 result = IVToken(vToken).repayBorrow(amount);
            require(result == 0, buildErrorMessage('Venus: repay', result));
        }
    }

    function getAssetMetadata(address platform, address asset)
        external
        override
        returns (AssetMetadata memory assetMetadata)
    {
        address vToken = getVToken(platform, asset);

        (, uint256 collateralFactor, ) = IVComptroller(platform).markets(vToken);
        uint256 estimatedRewardsPerYear = IVComptroller(platform).venusSpeeds(vToken).mul(BLOCKS_PER_YEAR);
        address rewardTokenAddress = IVComptroller(platform).getXVSAddress();

        assetMetadata.assetAddress = asset;
        assetMetadata.assetSymbol = ERC20(asset).symbol();
        assetMetadata.assetDecimals = ERC20(asset).decimals();
        assetMetadata.referencePrice = IVenusPriceOracle(IVComptroller(platform).oracle()).getUnderlyingPrice(vToken);
        assetMetadata.totalLiquidity = IVToken(vToken).getCash();
        assetMetadata.totalSupply = IVToken(vToken).totalSupply().mul(IVToken(vToken).exchangeRateCurrent()) / MANTISSA;
        assetMetadata.totalBorrow = IVToken(vToken).totalBorrowsCurrent();
        assetMetadata.totalReserves = IVToken(vToken).totalReserves();
        assetMetadata.supplyAPR = IVToken(vToken).supplyRatePerBlock().mul(BLOCKS_PER_YEAR);
        assetMetadata.borrowAPR = IVToken(vToken).borrowRatePerBlock().mul(BLOCKS_PER_YEAR);
        assetMetadata.rewardTokenAddress = rewardTokenAddress;
        assetMetadata.rewardTokenDecimals = ERC20(rewardTokenAddress).decimals();
        assetMetadata.rewardTokenSymbol = ERC20(rewardTokenAddress).symbol();
        assetMetadata.estimatedSupplyRewardsPerYear = estimatedRewardsPerYear;
        assetMetadata.estimatedBorrowRewardsPerYear = estimatedRewardsPerYear;
        assetMetadata.collateralFactor = collateralFactor;
        assetMetadata.liquidationFactor = collateralFactor;
        assetMetadata.canSupply = !IVComptroller(platform).mintGuardianPaused(vToken);
        assetMetadata.canBorrow = !IVComptroller(platform).borrowGuardianPaused(vToken);
    }

    /// @dev This receive function is only needed to allow for unit testing this connector.
    receive() external payable {}

    function redeemAll(address platform, address token) public override {
        uint256 startBalance = address(this).balance;
        address vToken = address(getVToken(platform, token));
        uint256 result = IVToken(vToken).redeem(IERC20(vToken).balanceOf(address(this)));
        require(result == 0, buildErrorMessage('Venus: redeemAll', result));

        if (token == address(WBNB)) {
            WBNB.deposit{ value: address(this).balance.sub(startBalance) }();
        }
    }

    /**
     * returns available liquidity in tokens
     */
    function getLiquidity(address platform, address token) public override returns (uint256) {
        (uint256 err, uint256 liquidity, uint256 shortfall) = IVComptroller(platform).getAccountLiquidity(
            address(this)
        );
        require(err == 0 && shortfall == 0, buildErrorMessage('Venus: getAccountLiquidity', err));
        // liquidity is in reference price, convert to token amount:
        uint256 price = getReferencePrice(platform, token);
        return liquidity.mul(1e18).div(price);
    }

    function accrueInterest(address platform, address token) public override {
        IVToken(getVToken(platform, token)).accrueInterest();
    }
}
