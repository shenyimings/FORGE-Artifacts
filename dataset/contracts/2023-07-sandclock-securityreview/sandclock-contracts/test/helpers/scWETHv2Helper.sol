// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {scWETHv2} from "../../src/steth/scWETHv2.sol";
import {PriceConverter} from "../../src/steth/PriceConverter.sol";
import {IAdapter} from "../../src/steth/IAdapter.sol";

/// @title helper contract for just the external view methods to be used by the backend
contract scWETHv2Helper {
    using FixedPointMathLib for uint256;

    scWETHv2 vault;
    PriceConverter priceConverter;

    constructor(scWETHv2 _vault, PriceConverter _priceConverter) {
        vault = _vault;
        priceConverter = _priceConverter;
    }

    function getCollateralInWeth(IAdapter adapter) public view returns (uint256) {
        return priceConverter.wstEthToEth(adapter.getCollateral(address(vault)));
    }

    /// @notice returns the net leverage that the strategy is using right now (1e18 = 100%)
    function getLeverage() public view returns (uint256) {
        uint256 collateral = priceConverter.wstEthToEth(vault.totalCollateral());
        return collateral > 0 ? collateral.divWadUp(collateral - vault.totalDebt()) : 0;
    }

    /// @notice returns the loan to value ration of the vault contract in a particular protocol
    /// @param adapter the address of the adapter contract of the protocol
    function getLtv(IAdapter adapter) public view returns (uint256) {
        uint256 collateral = getCollateralInWeth(adapter);

        if (collateral == 0) return 0;
        return vault.getDebt(adapter.id()).divWadDown(collateral);
    }

    /// @notice method to get the assets deposited in a particular lending market (in terms of weth)
    function getAssets(IAdapter adapter) external view returns (uint256) {
        return getCollateralInWeth(adapter) - vault.getDebt(adapter.id());
    }

    /// @notice returns the net LTV (Loan to Value) at which the vault has borrowed till now (1e18 = 100%)
    function getLtv() public view returns (uint256 ltv) {
        uint256 collateral = priceConverter.wstEthToEth(vault.totalCollateral());
        if (collateral > 0) {
            // getDebt / totalSupplied
            ltv = vault.totalDebt().divWadUp(collateral);
        }
    }

    /// @notice returns the asset allocation (in percent) in a particular protocol (1e18 = 100%)
    /// @param adapter the address of the adapter contract of the protocol
    function allocationPercent(IAdapter adapter) external view returns (uint256) {
        return (getCollateralInWeth(adapter) - vault.getDebt(adapter.id())).divWadDown(
            priceConverter.wstEthToEth(vault.totalCollateral()) - vault.totalDebt()
        );
    }
}
