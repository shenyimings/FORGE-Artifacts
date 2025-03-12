// SPDX-License-Identifier: AGPL-3.0-only

/*
    SkaleTokenInternalTester.sol - SKALE Allocator
    Copyright (C) 2018-Present SKALE Labs
    @author Dmytro Stebaiev

    SKALE Allocator is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    SKALE Allocator is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with SKALE Allocator.  If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity 0.6.10;

import "../Permissions.sol";
import "../interfaces/delegation/ITokenState.sol";
import "./interfaces/ILocker.sol";

contract TokenStateTester is Permissions, ITokenState {

    string[] private _lockers;

    function getAndUpdateForbiddenForDelegationAmount(address holder) external override returns (uint) {
        uint256 forbidden = 0;
        for (uint256 i = 0; i < _lockers.length; ++i) {
            ILocker locker = ILocker(contractManager.getContract(_lockers[i]));
            forbidden = forbidden.add(locker.getAndUpdateForbiddenForDelegationAmount(holder));
        }
        return forbidden;
    }

    function getAndUpdateLockedAmount(address holder) external override returns (uint) {
        uint256 locked = 0;
        for (uint256 i = 0; i < _lockers.length; ++i) {
            ILocker locker = ILocker(contractManager.getContract(_lockers[i]));
            locked = locked.add(locker.getAndUpdateLockedAmount(holder));
        }
        return locked;
    }

    function initialize(address contractManagerAddress) public override initializer {
        Permissions.initialize(contractManagerAddress);
        addLocker("DelegationController");
    }

    /**
     * @dev Allows the Owner to add a contract to the Locker.
     *
     * Emits a LockerWasAdded event.
     *
     * @param locker string name of contract to add to locker
     */
    function addLocker(string memory locker) public onlyOwner {
        _lockers.push(locker);
    }
}
