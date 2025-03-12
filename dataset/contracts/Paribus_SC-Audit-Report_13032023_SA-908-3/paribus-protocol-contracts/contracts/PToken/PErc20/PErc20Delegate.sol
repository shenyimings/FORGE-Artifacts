// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.5.17;

import "./PErc20.sol";

/**
 * @title Paribus's PErc20Delegate Contract
 * @notice PTokens which wrap an EIP-20 underlying and are delegated to
 * @author Compound, Paribus
 */
contract PErc20Delegate is PErc20, PTokenDelegateInterface {
    /**
     * @notice Construct an empty delegate
     */
    constructor() public {}

    /**
     * @notice Called by the delegator on a delegate to initialize it for duty. Should not be marked as pure
     * @param data The encoded bytes data for any initialization
     */
    function _becomeImplementation(bytes calldata data) external {
        data; // Shh -- currently unused
        require(msg.sender == admin, "only admin");
    }

    /**
     * @notice Called by the delegator on a delegate to forfeit its responsibility. Should not be marked as pure
     */
    function _resignImplementation() external {
        require(msg.sender == admin, "only admin");
    }
}
