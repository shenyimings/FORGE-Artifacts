// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Balance, Valuation } from "../../../interfaces/IAum.sol";
import { IInvestable, IInvestmentToken } from "../../../interfaces/IInvestable.sol";
import { InvestableDesc } from "../../../interfaces/IPortfolio.sol";

library PortfolioBaseAumLib {
    function getAssetBalances(InvestableDesc[] storage investableDescs)
        external
        view
        returns (Balance[] memory)
    {
        uint256 investableDescsLength = investableDescs.length;
        Balance[] memory assets = new Balance[](investableDescsLength);
        for (uint256 i = 0; i < investableDescsLength; i++) {
            IInvestable embeddedInvestable = investableDescs[i].investable;
            IInvestmentToken embeddedInvestmentToken = embeddedInvestable
                .getInvestmentToken();
            assets[i] = Balance(
                address(embeddedInvestmentToken),
                embeddedInvestmentToken.balanceOf(address(this))
            );
        }
        return assets;
    }

    function getAssetValuations(
        bool shouldMaximise,
        bool shouldIncludeAmmPrice,
        InvestableDesc[] storage investableDescs
    ) public view returns (Valuation[] memory) {
        uint256 investableDescsLength = investableDescs.length;

        Valuation[] memory assetValuations = new Valuation[](
            investableDescsLength
        );

        for (uint256 i = 0; i < investableDescsLength; i++) {
            IInvestable embeddedInvestable = investableDescs[i].investable;

            assetValuations[i] = Valuation(
                address(embeddedInvestable),
                (embeddedInvestable.getInvestmentTokenSupply() == 0)
                    ? 0
                    : ((embeddedInvestable.getEquityValuation(
                        shouldMaximise,
                        shouldIncludeAmmPrice
                    ) *
                        embeddedInvestable.getInvestmentTokenBalanceOf(
                            address(this)
                        )) / embeddedInvestable.getInvestmentTokenSupply())
            );
        }
        return assetValuations;
    }

    function getEquityValuation(
        bool shouldMaximise,
        bool shouldIncludeAmmPrice,
        InvestableDesc[] storage investableDescs
    ) external view returns (uint256) {
        uint256 equityValuation;

        Valuation[] memory assetValuations = getAssetValuations(
            shouldMaximise,
            shouldIncludeAmmPrice,
            investableDescs
        );
        uint256 assetValuationsLength = assetValuations.length;
        for (uint256 i = 0; i < assetValuationsLength; i++)
            equityValuation += assetValuations[i].valuation;

        return equityValuation;
    }
}
