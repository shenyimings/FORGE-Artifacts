// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {WadRay} from "libs/WadRay.sol";
import {SafeTransfer} from "kresko-lib/token/SafeTransfer.sol";
import {IERC20} from "kresko-lib/token/IERC20.sol";
import {cs} from "common/State.sol";
import {Asset} from "common/Types.sol";
import {wadUSD} from "common/funcs/Math.sol";
import {SDIPrice} from "common/funcs/Prices.sol";
import {Errors} from "common/Errors.sol";
import {SDIState} from "scdp/SState.sol";

library SDebtIndex {
    using SafeTransfer for IERC20;
    using WadRay for uint256;

    function valueToSDI(uint256 valueIn, uint8 oracleDecimals) internal view returns (uint256) {
        return (valueIn * 10 ** oracleDecimals).wadDiv(SDIPrice());
    }

    /// @notice Cover by pulling assets.
    function cover(
        SDIState storage self,
        address _assetAddr,
        uint256 _amount
    ) internal returns (uint256 shares, uint256 value) {
        if (_amount == 0) revert Errors.ZERO_AMOUNT(Errors.id(_assetAddr));
        Asset storage asset = cs().onlyCoverAsset(_assetAddr);

        value = wadUSD(_amount, asset.decimals, asset.price(), cs().oracleDecimals);
        self.totalCover += (shares = valueToSDI(value, cs().oracleDecimals));

        IERC20(_assetAddr).safeTransferFrom(msg.sender, self.coverRecipient, _amount);
    }

    /// @notice Returns the total effective debt amount of the SCDP.
    function effectiveDebt(SDIState storage self) internal view returns (uint256) {
        uint256 currentCover = self.totalCoverAmount();
        uint256 totalDebt = self.totalDebt;
        if (currentCover >= totalDebt) {
            return 0;
        }
        return (totalDebt - currentCover);
    }

    /// @notice Returns the total effective debt value of the SCDP.
    function effectiveDebtValue(SDIState storage self) internal view returns (uint256) {
        uint256 sdiPrice = SDIPrice();
        uint256 coverValue = self.totalCoverValue();
        uint256 coverAmount = coverValue != 0 ? coverValue.wadDiv(sdiPrice) : 0;
        uint256 totalDebt = self.totalDebt;

        if (coverValue == 0) return totalDebt.wadMul(sdiPrice);
        if (coverAmount >= totalDebt) return 0;

        return (totalDebt - coverAmount).wadMul(sdiPrice);
    }

    function totalCoverAmount(SDIState storage self) internal view returns (uint256) {
        return self.totalCoverValue().wadDiv(SDIPrice());
    }

    /// @notice Gets the total cover debt value, oracle precision
    function totalCoverValue(SDIState storage self) internal view returns (uint256 result) {
        address[] memory assets = self.coverAssets;
        for (uint256 i; i < assets.length; ) {
            unchecked {
                result += coverAssetValue(self, assets[i]);
                i++;
            }
        }
    }

    /// @notice Simply returns the total supply of SDI.
    function totalSDI(SDIState storage self) internal view returns (uint256) {
        return self.totalDebt + self.totalCoverAmount();
    }

    /// @notice Get total deposit value of `asset` in USD, oracle precision.
    function coverAssetValue(SDIState storage self, address _assetAddr) internal view returns (uint256) {
        uint256 bal = IERC20(_assetAddr).balanceOf(self.coverRecipient);
        if (bal == 0) return 0;

        Asset storage asset = cs().assets[_assetAddr];
        if (!asset.isCoverAsset) return 0;
        return (bal * asset.price()) / 10 ** asset.decimals;
    }
}
