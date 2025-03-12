// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {Gate} from "../Gate.sol";
import {Factory} from "../Factory.sol";

/// @title ERC20Gate
/// @author zefram.eth
/// @notice Abstract implementation of Gate for protocols using ERC20 vault shares.
abstract contract ERC20Gate is Gate {
    /// -----------------------------------------------------------------------
    /// Initialization
    /// -----------------------------------------------------------------------

    constructor(Factory factory_) Gate(factory_) {}

    /// -----------------------------------------------------------------------
    /// Getters
    /// -----------------------------------------------------------------------

    function getVaultShareBalance(address vault)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return ERC20(vault).balanceOf(address(this));
    }

    /// @inheritdoc Gate
    function vaultSharesIsERC20() public pure virtual override returns (bool) {
        return true;
    }

    /// @inheritdoc Gate
    function negativeYieldTokenName(address vault)
        external
        view
        virtual
        override
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    "Timeless ",
                    ERC20(vault).name(),
                    " Negative Yield Token"
                )
            );
    }

    /// @inheritdoc Gate
    function negativeYieldTokenSymbol(address vault)
        external
        view
        virtual
        override
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(unicode"∞-", ERC20(vault).symbol(), "-NYT")
            );
    }

    /// @inheritdoc Gate
    function perpetualYieldTokenName(address vault)
        external
        view
        virtual
        override
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    "Timeless ",
                    ERC20(vault).name(),
                    " Perpetual Yield Token"
                )
            );
    }

    /// @inheritdoc Gate
    function perpetualYieldTokenSymbol(address vault)
        external
        view
        virtual
        override
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(unicode"∞-", ERC20(vault).symbol(), "-PYT")
            );
    }
}
