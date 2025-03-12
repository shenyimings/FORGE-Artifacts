// SPDX-License-Identifier: Apache-2.0

/******************************************************************************
 * Copyright 2020 IEXEC BLOCKCHAIN TECH                                       *
 *                                                                            *
 * Licensed under the Apache License, Version 2.0 (the "License");            *
 * you may not use this file except in compliance with the License.           *
 * You may obtain a copy of the License at                                    *
 *                                                                            *
 *     http://www.apache.org/licenses/LICENSE-2.0                             *
 *                                                                            *
 * Unless required by applicable law or agreed to in writing, software        *
 * distributed under the License is distributed on an "AS IS" BASIS,          *
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   *
 * See the License for the specific language governing permissions and        *
 * limitations under the License.                                             *
 ******************************************************************************/

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IKYC.sol";


abstract contract KYC is IKYC, AccessControl
{
    bytes32 public constant override KYC_ADMIN_ROLE  = keccak256("KYC_ADMIN_ROLE");
    bytes32 public constant override KYC_MEMBER_ROLE = keccak256("KYC_MEMBER_ROLE");

    modifier onlyRole(bytes32 role, address member, string memory message)
    {
        require(hasRole(role, member), message);
        _;
    }

    constructor(address[] memory admins, address[] memory kycadmins)
    internal
    {
        _setRoleAdmin(KYC_MEMBER_ROLE, KYC_ADMIN_ROLE);
        for (uint256 i = 0; i < admins.length; ++i)
        {
            _setupRole(DEFAULT_ADMIN_ROLE, admins[i]);
        }
        for (uint256 i = 0; i < kycadmins.length; ++i)
        {
            _setupRole(KYC_ADMIN_ROLE, kycadmins[i]);
        }
    }

    function isKYC(address account)
    public view override returns (bool)
    {
        return hasRole(KYC_MEMBER_ROLE, account);
    }

    function grantKYC(address[] calldata accounts)
    external virtual override
    {
        for (uint256 i = 0; i < accounts.length; ++i)
        {
            grantRole(KYC_MEMBER_ROLE, accounts[i]);
        }
    }

    function revokeKYC(address[] calldata accounts)
    external virtual override
    {
        for (uint256 i = 0; i < accounts.length; ++i)
        {
            revokeRole(KYC_MEMBER_ROLE, accounts[i]);
        }
    }
}
