// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import { MarketParameters, AssetRateAdapter, NotionalGovernance, NotionalViews } from "../src/external/notional/interfaces/INotional.sol";
import { IWrappedfCashComplete, IWrappedfCash } from "../src/external/notional/interfaces/IWrappedfCash.sol";
import "../src/external/notional/wfCashERC4626.sol";
import "../src/external/notional/proxy/WrappedfCashFactory.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "../src/FRPVault.sol";

contract WrappedfCashTest is Test {
    using stdStorage for StdStorage;

    address notionalRouter = address(0x1344A36A1B56144C3Bc62E7757377D288fDE0369);
    address usdcWhale = address(0x0A59649758aa4d66E25f08Dd01271e891fe52199);
    ERC20Upgradeable usdc = ERC20Upgradeable(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));

    uint16 currencyId = 3;

    address wrappedfCashFactory = address(0x5D051DeB5db151C2172dCdCCD42e6A2953E27261);

    string mainnetHttpsUrl;
    uint mainnetFork;

    function testfCashWithdrawal() public {
        vm.startPrank(usdcWhale);
        mainnetHttpsUrl = vm.envString("MAINNET_HTTPS_URL");
        mainnetFork = vm.createSelectFork(mainnetHttpsUrl, 15_364_981);
        MarketParameters[] memory marketParameters = NotionalViews(notionalRouter).getActiveMarkets(currencyId);
        uint maturity = marketParameters[0].maturity;
        console.log("oracleRate is: ", marketParameters[0].oracleRate);
        console.log("spot rate is: ", marketParameters[0].lastImpliedRate);
        IWrappedfCashComplete fCash = IWrappedfCashComplete(
            IWrappedfCashFactory(wrappedfCashFactory).deployWrapper(currencyId, uint40(maturity))
        );
        usdc.approve(address(fCash), type(uint).max);

        uint assetsToDeposit = 100_000 * 1e6;
        fCash.deposit(assetsToDeposit, usdcWhale);
        uint usdcBalanceBefore = usdc.balanceOf(usdcWhale);

        uint withdrawAmount = 90_000 * 1e6;
        uint shares = fCash.previewWithdraw(withdrawAmount);
        // I have tried using both redeem and redeemToUnderlying and they return the same result
        //        fCash.redeem(shares, usdcWhale, usdcWhale);
        fCash.redeemToUnderlying(shares, usdcWhale, type(uint32).max);
        uint usdcBalanceAfter = usdc.balanceOf(usdcWhale);
        uint netUsdcBalance = usdcBalanceAfter - usdcBalanceBefore;
        console.log("amount underestimated is: ", withdrawAmount - netUsdcBalance); // This should return 37
        console.log("amount requested is: ", withdrawAmount);
        console.log("amount actually recieved is: ", netUsdcBalance);
        vm.stopPrank();
    }
}
