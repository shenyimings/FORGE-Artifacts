// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./IOwnable.sol";

/**
 * @dev Ownable with an additional role of operator
 */
interface IOwnableWithOperator is IOwnable {
    /**
     * @dev Returns the current operator.
     */
    function operator() external view returns (address);
}
