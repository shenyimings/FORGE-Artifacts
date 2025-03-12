// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import {IWrappedERC20, ERC20Wrapper} from "@animoca/ethereum-contracts-core-1.1.1/contracts/utils/ERC20Wrapper.sol";
import {ManagedIdentity} from "@animoca/ethereum-contracts-core-1.1.1/contracts/metatx/ManagedIdentity.sol";
import {ERC20BasePredicate} from "./ERC20BasePredicate.sol";

/**
 * Polygon (MATIC) bridging ERC20 escrowing predicate to be deployed on the root chain (Ethereum mainnet).
 * This predicate must be used for non-mintable/non-burnable tokens.
 */
contract ERC20EscrowPredicate is ERC20BasePredicate, ManagedIdentity {
    using ERC20Wrapper for IWrappedERC20;

    constructor(address rootChainManager_) ERC20BasePredicate(rootChainManager_) {}

    /**
     * Locks ERC20 tokens for deposit.
     * @dev Reverts if not called by the manager (RootChainManager).
     * @param depositor Address who wants to deposit tokens.
     * @param depositReceiver Address (address) who wants to receive tokens on child chain.
     * @param rootToken Token which gets deposited.
     * @param depositData ABI encoded amount.
     */
    function lockTokens(
        address depositor,
        address depositReceiver,
        address rootToken,
        bytes calldata depositData
    ) external override {
        _requireManagerRole(_msgSender());
        uint256 amount = abi.decode(depositData, (uint256));
        emit LockedERC20(depositor, depositReceiver, rootToken, amount);
        IWrappedERC20(rootToken).wrappedTransferFrom(depositor, address(this), amount);
    }

    /**
     * Validates the {Withdrawn} log signature, then sends the correct amount to withdrawer.
     * @dev Reverts if not called only by the manager (RootChainManager).
     * @param rootToken Token which gets withdrawn
     * @param log Valid ERC20 burn log from child chain
     */
    function exitTokens(
        address,
        address rootToken,
        bytes memory log
    ) public override {
        _requireManagerRole(_msgSender());
        (address withdrawer, uint256 amount) = _verifyWithdrawalLog(log);
        IWrappedERC20(rootToken).wrappedTransfer(withdrawer, amount);
    }
}
