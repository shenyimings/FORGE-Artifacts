// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

// contracts
import {SafeERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Vault} from "../../contracts/Vault.sol";

// interfaces
import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// libraries
import {LibReserve} from "../../contracts/lib/LibReserve.sol";

/*
 * TestVault includes some setter functions to edit part of
 * the internal state of Vault which aren't exposed otherwise.
 */
contract TestVault is Vault {
    using SafeERC20 for IERC20Metadata;

    constructor(IERC20Metadata _ua) Vault(_ua) {}

    function __TestVault__getUserReserveValue(address user, bool isDiscounted) external view returns (int256) {
        return _getUserReserveValue(user, isDiscounted);
    }

    /// @notice Set trader balance without any actual token transfer
    function __TestVault__changeTraderBalance(address user, uint256 tokenIdx, int256 amount) external {
        return _changeBalance(user, tokenIdx, amount);
    }

    /// @notice Set lp balance without any actual token transfer
    function __TestVault__changeLpBalance(address user, uint256 tokenIdx, int256 amount) external {
        return _changeBalance(user, tokenIdx, amount);
    }

    /// @notice Empty out the vault without adjusting the internal user accounting
    function __TestVault__transferOut(
        address user,
        IERC20Metadata withdrawToken,
        uint256 amount // 1e18
    ) external {
        // get asset
        uint256 tokenIdx = tokenToCollateralIdx[withdrawToken];

        // adjust global balances
        whiteListedCollaterals[tokenIdx].currentAmount -= amount;

        // withdraw
        uint256 tokenAmount = LibReserve.wadToToken(whiteListedCollaterals[tokenIdx].decimals, amount);
        IERC20Metadata(withdrawToken).safeTransfer(user, tokenAmount);
    }

    function __TestVault__getUndiscountedCollateralUSDValue(IERC20Metadata collateralAsset, int256 collateralBalance)
        external
        view
        returns (int256)
    {
        return _getUndiscountedCollateralUSDValue(collateralAsset, collateralBalance);
    }
}
