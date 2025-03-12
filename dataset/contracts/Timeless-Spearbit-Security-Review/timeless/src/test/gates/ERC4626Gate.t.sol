// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";

import {Gate} from "../../Gate.sol";
import {FullMath} from "../../lib/FullMath.sol";
import {ERC4626Gate} from "../../gates/ERC4626Gate.sol";
import {BaseGateTest} from "../base/BaseGateTest.sol";
import {TestERC4626} from "../mocks/TestERC4626.sol";

contract ERC4626GateTest is BaseGateTest {
    function _deployGate() internal virtual override returns (Gate gate_) {
        return new ERC4626Gate(factory);
    }

    function _deployVault(ERC20 underlying)
        internal
        virtual
        override
        returns (address vault)
    {
        return address(new TestERC4626(underlying));
    }

    function _depositInVault(address vault, uint256 underlyingAmount)
        internal
        virtual
        override
        returns (uint256)
    {
        if (underlyingAmount == 0) return 0;
        return TestERC4626(vault).deposit(underlyingAmount, address(this));
    }

    function _getExpectedNYTName()
        internal
        virtual
        override
        returns (string memory)
    {
        return "Timeless TestERC4626 Negative Yield Token";
    }

    function _getExpectedNYTSymbol()
        internal
        virtual
        override
        returns (string memory)
    {
        return unicode"∞-TEST-ERC4626-NYT";
    }

    function _getExpectedPYTName()
        internal
        virtual
        override
        returns (string memory)
    {
        return "Timeless TestERC4626 Perpetual Yield Token";
    }

    function _getExpectedPYTSymbol()
        internal
        virtual
        override
        returns (string memory)
    {
        return unicode"∞-TEST-ERC4626-PYT";
    }

    function _vaultSharesAmountToUnderlyingAmount(
        address vault,
        uint256 vaultSharesAmount
    ) internal view virtual override returns (uint256) {
        return ERC4626(vault).convertToAssets(vaultSharesAmount);
    }

    function _underlyingAmountToVaultSharesAmount(
        address vault,
        uint256 underlyingAmount
    ) internal view virtual override returns (uint256) {
        return ERC4626(vault).convertToShares(underlyingAmount);
    }

    function _shouldExpectExitToUnderlyingRevert(
        address vault,
        uint256 underlyingAmount
    ) internal virtual override returns (bool) {
        return
            ERC4626(vault).balanceOf(address(gate)) <
            ERC4626(vault).previewWithdraw(underlyingAmount);
    }

    function _shouldExpectExitToVaultSharesRevert(
        address vault,
        uint256 vaultSharesAmount
    ) internal virtual override returns (bool) {
        return ERC4626(vault).balanceOf(address(gate)) < vaultSharesAmount;
    }
}
