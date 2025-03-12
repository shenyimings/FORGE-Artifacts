// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ISeals} from "./../interfaces/ISeals.sol";
import {SealsStorage} from "./../libraries/SealsStorage.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

/// @title Uniquely identified seals management (proxiable version).
abstract contract SealsBase is ISeals, Context {
    using SealsStorage for SealsStorage.Layout;

    /// @notice Retrieves whether a seal has been used already.
    /// @param sealId the seal identifier.
    /// @return wasSealed Whether a seal has been used already.
    function isSealed(uint256 sealId) external view returns (bool wasSealed) {
        return SealsStorage.layout().isSealed(sealId);
    }
}
