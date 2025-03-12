// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DnsVectorStrategyCommon.sol";
import "./DnsVectorStrategyStorageLib.sol";
import "../../interfaces/IAum.sol";

library DnsVectorStrategyAumLib {
    function getAssetBalances() public view returns (Balance[] memory) {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();
        Balance[] memory assetBalances = new Balance[](2);
        assetBalances[0] = Balance(
            address(strategyStorage.aAaveSupplyToken),
            strategyStorage.aAaveSupplyToken.balanceOf(address(this))
        );
        assetBalances[1] = Balance(
            address(strategyStorage.pangolinPair),
            DnsVectorStrategyCommon.getPangolinLpBalance()
        );

        return assetBalances;
    }

    function getLiabilityBalances() public view returns (Balance[] memory) {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();
        Balance[] memory liabilityBalances = new Balance[](1);
        liabilityBalances[0] = Balance(
            address(strategyStorage.vAaveBorrowToken),
            strategyStorage.vAaveBorrowToken.balanceOf(address(this))
        );
        return liabilityBalances;
    }

    function getAssetValuations(bool shouldMaximise, bool shouldIncludeAmmPrice)
        external
        view
        returns (Valuation[] memory)
    {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();
        Valuation[] memory assetValuations = new Valuation[](2);
        // assuming aaveSupplyToken == depositToken
        assetValuations[0] = Valuation(
            address(strategyStorage.aAaveSupplyToken),
            strategyStorage.aAaveSupplyToken.balanceOf(address(this))
        );

        (
            uint256 ammPairDepositTokenReserve,
            uint256 aaveBorrowTokenReserve
        ) = DnsVectorStrategyCommon.getPangolinLpReserve(
                address(strategyStorage.ammPairDepositToken),
                address(strategyStorage.aaveBorrowToken)
            );

        uint256 lpTokenTotalSupply = DnsVectorStrategyCommon
            .getPangolinLpTotalSupply();
        uint256 lpTokenContractBalance = DnsVectorStrategyCommon
            .getPangolinLpBalance();

        // get the aaveBorrowToken AUM in depositToken
        uint256 lpBorrowTokenAumInDepositToken = (aaveBorrowTokenReserve *
            lpTokenContractBalance *
            strategyStorage.priceOracle.getPrice(
                strategyStorage.aaveBorrowToken,
                shouldMaximise,
                shouldIncludeAmmPrice
            )) /
            lpTokenTotalSupply /
            10**18;

        // assuming ammPairDepositToken == depositToken
        // get the ammPairDepositToken AUM in depositToken
        uint256 lpPairDepositAumInDepositToken = (ammPairDepositTokenReserve *
            lpTokenContractBalance) / lpTokenTotalSupply;

        assetValuations[1] = Valuation(
            address(strategyStorage.pangolinPair),
            lpBorrowTokenAumInDepositToken + lpPairDepositAumInDepositToken
        );

        return assetValuations;
    }

    function getLiabilityValuations(
        bool shouldMaximise,
        bool shouldIncludeAmmPrice
    ) external view returns (Valuation[] memory) {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        Valuation[] memory liabilityValuations = new Valuation[](1);
        liabilityValuations[0] = Valuation(
            address(strategyStorage.vAaveBorrowToken),
            (strategyStorage.vAaveBorrowToken.balanceOf(address(this)) *
                (
                    strategyStorage.priceOracle.getPrice(
                        strategyStorage.aaveBorrowToken,
                        shouldMaximise,
                        shouldIncludeAmmPrice
                    )
                )) / 10**18
        );
        return liabilityValuations;
    }

    function getAaveDebt() external view returns (uint256) {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();
        return strategyStorage.vAaveBorrowToken.balanceOf(address(this));
    }

    function getAaveSupply() external view returns (uint256) {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();
        return strategyStorage.aAaveSupplyToken.balanceOf(address(this));
    }

    function getPoolDebt() external view returns (uint256) {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        (uint256 aaveBorrowTokenReserve, ) = DnsVectorStrategyCommon
            .getPangolinLpReserve(
                address(strategyStorage.aaveBorrowToken),
                address(strategyStorage.ammPairDepositToken)
            );

        uint256 lpTokenTotalSupply = DnsVectorStrategyCommon
            .getPangolinLpTotalSupply();
        uint256 lpTokenContractBalance = DnsVectorStrategyCommon
            .getPangolinLpBalance();

        return
            (aaveBorrowTokenReserve * lpTokenContractBalance) /
            lpTokenTotalSupply;
    }

    function getInverseCollateralRatio(
        bool shouldMaximise,
        bool shouldIncludeAmmPrice
    ) external view returns (uint256) {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();
        Balance[] memory assetBalances = getAssetBalances();
        Balance[] memory liabilityBalances = getLiabilityBalances();

        // assuming aAaveSupplyToken == depositToken
        // assuming aAaveSupplyToken is at index 0 of getAssetBalances()
        // assuming vAaveBorrowToken is at index 0 of getLiabilityBalances()
        return
            (((strategyStorage.priceOracle.getPrice(
                strategyStorage.aaveBorrowToken,
                shouldMaximise,
                shouldIncludeAmmPrice
            ) * liabilityBalances[0].balance) *
                Math.SHORT_FIXED_DECIMAL_FACTOR) / 10**18) /
            (assetBalances[0].balance);
    }
}
