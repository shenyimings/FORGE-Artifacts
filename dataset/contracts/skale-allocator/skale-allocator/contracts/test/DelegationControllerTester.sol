// SPDX-License-Identifier: AGPL-3.0-only

/*
    DelegationControllerTester.sol - SKALE Allocator
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
import "../interfaces/delegation/IDelegationController.sol";
import "./interfaces/ILocker.sol";
import "./TokenStateTester.sol";
import "./SkaleTokenTester.sol";

contract DelegationControllerTester is Permissions, IDelegationController, ILocker {

    struct Delegation {
        address holder;
        uint256 amount;
    }

    mapping (address => uint) private _locked;
    Delegation[] private _delegations;

    function delegate(
        uint256 ,
        uint256 amount,
        uint256 ,
        string calldata
    )
        external
        override
    {
        SkaleTokenTester skaleToken = SkaleTokenTester(contractManager.getContract("SkaleToken"));
        TokenStateTester tokenState = TokenStateTester(contractManager.getContract("TokenState"));
        _delegations.push(Delegation({
            holder: msg.sender,
            amount: amount
        }));
        _locked[msg.sender] += amount;
        uint256 holderBalance = skaleToken.balanceOf(msg.sender);
        uint256 forbiddenForDelegation = tokenState.getAndUpdateForbiddenForDelegationAmount(msg.sender);
        require(holderBalance >= forbiddenForDelegation, "Token holder does not have enough tokens to delegate");
    }

    function requestUndelegation(uint256 delegationId) external override {
        address holder = _delegations[delegationId].holder;
        _locked[holder] -= _delegations[delegationId].amount;
    }

    function cancelPendingDelegation(uint delegationId) external override {
        address holder = _delegations[delegationId].holder;
        _locked[holder] -= _delegations[delegationId].amount;
    }

    /**
     * @dev See ILocker.
     */
    function getAndUpdateLockedAmount(address wallet) external override returns (uint) {
        return _getAndUpdateLockedAmount(wallet);
    }

    /**
     * @dev See ILocker.
     */
    function getAndUpdateForbiddenForDelegationAmount(address wallet) external override returns (uint) {
        return _getAndUpdateLockedAmount(wallet);
    }

    function initialize(address contractManagerAddress) public override initializer {
        Permissions.initialize(contractManagerAddress);
    }

    function _getAndUpdateLockedAmount(address wallet) private view returns (uint) {
        return _locked[wallet];
    }
}
