// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { LibDiamond } from "../Libraries/LibDiamond.sol";
import { LibAccess } from "../Libraries/LibAccess.sol";
import { IAccessManagerFacet } from "../Interfaces/IAccessManagerFacet.sol";
import { CannotAuthoriseSelf } from "../Errors/GenericErrors.sol";

/// @title Access Manager Facet
/// @notice Provides functionality for managing method level access control
contract AccessManagerFacet is IAccessManagerFacet {
    /// @inheritdoc IAccessManagerFacet
    function setCanExecute(
        bytes4 _selector,
        address _executor,
        bool _canExecute
    ) external override {
        if (_executor == address(this)) {
            revert CannotAuthoriseSelf();
        }
        LibDiamond.enforceIsContractOwner();
        _canExecute
            ? LibAccess.addAccess(_selector, _executor)
            : LibAccess.removeAccess(_selector, _executor);
        if (_canExecute) {
            emit ExecutionAllowed(_executor, _selector);
        } else {
            emit ExecutionDenied(_executor, _selector);
        }
    }

    /// @inheritdoc IAccessManagerFacet
    function addressCanExecuteMethod(
        bytes4 _selector,
        address _executor
    ) external view override returns (bool) {
        return LibAccess.accessStorage().execAccess[_selector][_executor];
    }
}
