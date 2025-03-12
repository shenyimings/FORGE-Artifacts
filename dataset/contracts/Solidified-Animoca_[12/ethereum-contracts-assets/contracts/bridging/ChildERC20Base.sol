// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import {IChildToken} from "@animoca/ethereum-contracts-core-1.1.1/contracts/bridging/IChildToken.sol";
import {ERC20Receiver} from "../token/ERC20/ERC20Receiver.sol";

/**
 * Polygon (MATIC) bridging base child ERC20 for deployment on the child chain (Polygon/MATIC).
 */
abstract contract ChildERC20Base is IChildToken, ERC20Receiver {
    event Withdrawn(address account, uint256 value);

    // see https://github.com/maticnetwork/pos-portal/blob/master/contracts/child/ChildChainManager/ChildChainManager.sol
    address public childChainManager;

    /**
     * Constructor
     * @param childChainManager_ the Polygon/MATIC ChildChainManager proxy address.
     */
    constructor(address childChainManager_) {
        childChainManager = childChainManager_;
    }

    function _requireDepositorRole(address account) internal view {
        require(account == childChainManager, "ChildERC20: only depositor");
    }
}
