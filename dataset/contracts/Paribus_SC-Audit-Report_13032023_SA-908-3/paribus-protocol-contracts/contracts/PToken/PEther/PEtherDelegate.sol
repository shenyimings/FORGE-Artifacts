// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.5.17;

import "./PEther.sol";

/**
 * @title Paribus's PEtherDelegate Contract
 * @notice PTokens which wraps network native token and are delegated to
 * @author Compound, Paribus
 */
contract PEtherDelegate is PEther, PTokenDelegateInterface {
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
        require(msg.sender == admin, "only the admin may call _becomeImplementation");
    }

    /**
     * @notice Called by the delegator on a delegate to forfeit its responsibility. Should not be marked as pure
     */
    function _resignImplementation() external {
        require(msg.sender == admin, "only the admin may call _resignImplementation");
    }
}
