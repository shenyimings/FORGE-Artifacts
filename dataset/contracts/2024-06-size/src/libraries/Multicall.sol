// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {State} from "@src/SizeStorage.sol";
import {CapsLibrary} from "@src/libraries/CapsLibrary.sol";
import {RiskLibrary} from "@src/libraries/RiskLibrary.sol";

/// @notice Provides a function to batch together multiple calls in a single external call.
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @author OpenZeppelin (https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/utils/Multicall.sol), Size
/// @dev Add `payable` keyword to OpenZeppelin multicall implementation
///      Functions should not rely on `msg.value`. See the security implications of this change:
///        - https://github.com/sherlock-audit/2023-06-tokemak-judging/issues/215
///        - https://github.com/Uniswap/v3-periphery/issues/52
///        - https://forum.openzeppelin.com/t/query-regarding-multicall-fucntion-in-multicallupgradeable-sol/35537
///        - https://twitter.com/haydenzadams/status/1427784837738418180?lang=en
library Multicall {
    using CapsLibrary for State;
    using RiskLibrary for State;

    /// @dev Receives and executes a batch of function calls on this contract.
    /// @custom:oz-upgrades-unsafe-allow-reachable delegatecall
    function multicall(State storage state, bytes[] calldata data) internal returns (bytes[] memory results) {
        state.data.isMulticall = true;

        uint256 borrowATokenSupplyBefore = state.data.borrowAToken.balanceOf(address(this));
        uint256 debtTokenSupplyBefore = state.data.debtToken.totalSupply();

        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = Address.functionDelegateCall(address(this), data[i]);
        }

        uint256 borrowATokenSupplyAfter = state.data.borrowAToken.balanceOf(address(this));
        uint256 debtTokenSupplyAfter = state.data.debtToken.totalSupply();

        state.validateBorrowATokenIncreaseLteDebtTokenDecrease(
            borrowATokenSupplyBefore, debtTokenSupplyBefore, borrowATokenSupplyAfter, debtTokenSupplyAfter
        );

        state.data.isMulticall = false;
    }
}
