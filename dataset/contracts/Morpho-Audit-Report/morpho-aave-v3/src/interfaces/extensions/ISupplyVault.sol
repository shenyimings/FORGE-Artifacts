// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

import {IERC4626Upgradeable} from "@openzeppelin-upgradeable/interfaces/IERC4626Upgradeable.sol";
import {IMorpho} from "src/interfaces/IMorpho.sol";

interface ISupplyVault is IERC4626Upgradeable {
    /* EVENTS */

    /// @notice Emitted when max iterations is set.
    /// @param maxIterations The max iterations.
    event MaxIterationsSet(uint96 maxIterations);

    /// @notice Emitted when the recipient is set.
    /// @param recipient The recipient.
    event RecipientSet(address indexed recipient);

    /// @notice Emitted when tokens are skimmed to `recipient`.
    /// @param token The token being skimmed.
    /// @param recipient The recipient.
    /// @param amount The amount of tokens transferred.
    event Skimmed(address indexed token, address indexed recipient, uint256 amount);

    /* ERRORS */

    /// @notice Thrown when an address used as parameter is the zero address.
    error AddressIsZero();

    /// @notice Thrown when the initial deposit at initialization is zero.
    error InitialDepositIsZero();

    /* EXTERNAL */

    function MORPHO() external view returns (IMorpho);

    function recipient() external view returns (address);

    function maxIterations() external view returns (uint96);

    function skim(address[] calldata tokens) external;

    function setMaxIterations(uint96 newMaxIterations) external;

    function setRecipient(address newRecipient) external;
}
