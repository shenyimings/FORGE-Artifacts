// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IERC20 } from '../interfaces/IERC20.sol';
import { TokenLinkerBase } from './TokenLinkerBase.sol';

contract TokenLinkerLockUnlock is TokenLinkerBase {
    error TransferFailed();
    error TransferFromFailed();

    address public immutable tokenAddress;

    constructor(
        address gatewayAddress_,
        address gasServiceAddress_,
        address tokenAddress_
    ) TokenLinkerBase(gatewayAddress_, gasServiceAddress_) {
        if (tokenAddress_ == address(0)) revert InvalidAddress();

        tokenAddress = tokenAddress_;
    }

    function _giveToken(address to, uint256 amount) internal override {
        (bool success, bytes memory returnData) = tokenAddress.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        bool transferred = success && (returnData.length == uint256(0) || abi.decode(returnData, (bool)));

        if (!transferred || tokenAddress.code.length == 0) revert TransferFailed();
    }

    function _takeToken(address from, uint256 amount) internal override {
        (bool success, bytes memory returnData) = tokenAddress.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, address(this), amount)
        );
        bool transferred = success && (returnData.length == uint256(0) || abi.decode(returnData, (bool)));

        if (!transferred || tokenAddress.code.length == 0) revert TransferFromFailed();
    }
}
