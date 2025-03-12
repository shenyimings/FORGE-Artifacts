//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../state/shared/AdministratorAddress.sol";
import "../state/shared/PendingAdministratorAddress.sol";

library LibOwnable {
    function _setAdmin(address newAdmin) internal {
        AdministratorAddress.set(newAdmin);
    }

    function _getAdmin() internal view returns (address) {
        return AdministratorAddress.get();
    }

    function _setPendingAdmin(address newAdmin) internal {
        PendingAdministratorAddress.set(newAdmin);
    }

    function _getPendingAdmin() internal view returns (address) {
        return PendingAdministratorAddress.get();
    }
}
