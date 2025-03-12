// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './IComptroller.sol';
import './ICToken.sol';
import './ICEther.sol';
import './ICompoundPriceOracle.sol';
import '../ILendingPlatform.sol';
import '../../../core/interfaces/ICTokenProvider.sol';
import '../../../../Libs/IWETH.sol';
import '../../../../Libs/Uint2Str.sol';

contract CompoundForksLendingAdapter is ILendingPlatform, Uint2Str {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IWETH public immutable WETH; //0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    ICTokenProvider public immutable cTokenProvider;

    uint256 private constant BLOCKS_PER_YEAR = 365 * 24 * 60 * 4;
    uint256 private constant MANTISSA = 1e18;

    constructor(address wethAddress, address cTokenProviderAddress) public {
        require(wethAddress != address(0), 'ICP0');
        require(cTokenProviderAddress != address(0), 'ICP0');
        WETH = IWETH(wethAddress);
        cTokenProvider = ICTokenProvider(cTokenProviderAddress);
    }

    // Maps a token to its corresponding cToken
    function getCToken(address platform, address token) private view returns (address) {
        return cTokenProvider.getCToken(platform, token);
    }

    function buildErrorMessage(string memory message, uint256 code) private pure returns (string memory) {
        return string(abi.encodePacked(message, ': ', uint2str(code)));
    }

    function getCollateralUsageFactor(address platform) external override returns (uint256) {
        uint256 sumCollateral = 0;
        uint256 sumBorrows = 0;

        address priceOracle = IComptroller(platform).oracle();

        // For each asset the account is in
        address[] memory assets = IComptroller(platform).getAssetsIn(address(this));
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];

            uint256 borrowBalance = ICToken(asset).borrowBalanceCurrent(address(this));
            uint256 supplyBalance = ICToken(asset).balanceOfUnderlying(address(this));

            // Get collateral factor for this asset
            (, uint256 collateralFactor, ) = IComptroller(platform).markets(asset);

            // Get the normalized price of the asset
            uint256 oraclePrice = ICompoundPriceOracle(priceOracle).getUnderlyingPrice(asset);

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
        (, collateralFactor, ) = IComptroller(platform).markets(getCToken(platform, asset));
    }

    /// @dev Compound returns reference prices with regard to USD scaled by 1e18. Decimals disparity is taken into account
    function getReferencePrice(address platform, address token) public override returns (uint256) {
        address cToken = getCToken(platform, token);

        address priceOracle = IComptroller(platform).oracle();
        uint256 oraclePrice = ICompoundPriceOracle(priceOracle).getUnderlyingPrice(cToken);
        return oraclePrice;
    }

    function getBorrowBalance(address platform, address token) external override returns (uint256 borrowBalance) {
        return ICToken(getCToken(platform, token)).borrowBalanceCurrent(address(this));
    }

    function getSupplyBalance(address platform, address token) external override returns (uint256 supplyBalance) {
        return ICToken(getCToken(platform, token)).balanceOfUnderlying(address(this));
    }

    function claimRewards(address platform) public override returns (address rewardsToken, uint256 rewardsAmount) {
        rewardsToken = IComptroller(platform).getCompAddress();
        rewardsAmount = IERC20(rewardsToken).balanceOf(address(this));

        IComptroller(platform).claimComp(address(this));

        rewardsAmount = IERC20(rewardsToken).balanceOf(address(this)).sub(rewardsAmount);
    }

    function enterMarkets(address platform, address[] calldata markets) external override {
        address[] memory cTokens = new address[](markets.length);
        for (uint256 i = 0; i < markets.length; i++) {
            cTokens[i] = getCToken(platform, markets[i]);
        }
        uint256[] memory results = IComptroller(platform).enterMarkets(cTokens);
        for (uint256 i = 0; i < results.length; i++) {
            require(results[i] == 0, buildErrorMessage('CFLA1', results[i]));
        }
    }

    function supply(
        address platform,
        address token,
        uint256 amount
    ) external override {
        address cToken = getCToken(platform, token);

        if (token == address(WETH)) {
            WETH.withdraw(amount);
            ICEther(cToken).mint{ value: amount }();
        } else {
            IERC20(token).safeIncreaseAllowance(cToken, amount);
            uint256 result = ICToken(cToken).mint(amount);
            require(result == 0, buildErrorMessage('CFLA2', result));
        }
    }

    function borrow(
        address platform,
        address token,
        uint256 amount
    ) external override {
        address cToken = getCToken(platform, token);

        uint256 result = ICToken(cToken).borrow(amount);
        require(result == 0, buildErrorMessage('CFLA3', result));

        if (token == address(WETH)) {
            WETH.deposit{ value: amount }();
        }
    }

    function redeemSupply(
        address platform,
        address token,
        uint256 amount
    ) external override {
        address cToken = address(getCToken(platform, token));

        uint256 result = ICToken(cToken).redeemUnderlying(amount);
        require(result == 0, buildErrorMessage('CFLA4', result));

        if (token == address(WETH)) {
            WETH.deposit{ value: amount }();
        }
    }

    function repayBorrow(
        address platform,
        address token,
        uint256 amount
    ) external override {
        address cToken = address(getCToken(platform, token));

        if (token == address(WETH)) {
            WETH.withdraw(amount);
            ICEther(cToken).repayBorrow{ value: amount }();
        } else {
            IERC20(token).safeIncreaseAllowance(cToken, amount);
            uint256 result = ICToken(cToken).repayBorrow(amount);
            require(result == 0, buildErrorMessage('CFLA5', result));
        }
    }

    function getAssetMetadata(address platform, address asset)
        external
        override
        returns (AssetMetadata memory assetMetadata)
    {
        address cToken = getCToken(platform, asset);

        (, uint256 collateralFactor, ) = IComptroller(platform).markets(cToken);
        address rewardTokenAddress = IComptroller(platform).getCompAddress();

        assetMetadata.assetAddress = asset;
        assetMetadata.assetSymbol = ERC20(asset).symbol();
        assetMetadata.assetDecimals = ERC20(asset).decimals();
        assetMetadata.referencePrice = ICompoundPriceOracle(IComptroller(platform).oracle()).getUnderlyingPrice(cToken);
        assetMetadata.totalLiquidity = ICToken(cToken).getCash();
        assetMetadata.totalSupply = ICToken(cToken).totalSupply().mul(ICToken(cToken).exchangeRateCurrent()) / MANTISSA;
        assetMetadata.totalBorrow = ICToken(cToken).totalBorrowsCurrent();
        assetMetadata.totalReserves = ICToken(cToken).totalReserves();
        assetMetadata.supplyAPR = ICToken(cToken).supplyRatePerBlock().mul(BLOCKS_PER_YEAR);
        assetMetadata.borrowAPR = ICToken(cToken).borrowRatePerBlock().mul(BLOCKS_PER_YEAR);
        assetMetadata.rewardTokenAddress = rewardTokenAddress;
        assetMetadata.rewardTokenDecimals = ERC20(rewardTokenAddress).decimals();
        assetMetadata.rewardTokenSymbol = ERC20(rewardTokenAddress).symbol();
        assetMetadata.estimatedSupplyRewardsPerYear = IComptroller(platform).compSupplySpeeds(cToken).mul(
            BLOCKS_PER_YEAR
        );
        assetMetadata.estimatedBorrowRewardsPerYear = IComptroller(platform).compBorrowSpeeds(cToken).mul(
            BLOCKS_PER_YEAR
        );
        assetMetadata.collateralFactor = collateralFactor;
        assetMetadata.liquidationFactor = collateralFactor;
        assetMetadata.canSupply = !IComptroller(platform).mintGuardianPaused(cToken);
        assetMetadata.canBorrow = !IComptroller(platform).borrowGuardianPaused(cToken);
    }

    /// @dev This receive function is only needed to allow for unit testing this connector.
    receive() external payable {}
}
