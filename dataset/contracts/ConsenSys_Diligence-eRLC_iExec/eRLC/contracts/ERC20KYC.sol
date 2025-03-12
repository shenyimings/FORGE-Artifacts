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

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IERC20KYC.sol";
import "./KYC.sol";


abstract contract ERC20KYC is IERC20KYC, ERC20, KYC
{
    uint8 internal constant _RESTRICTION_OK               = uint8(0);
    uint8 internal constant _RESTRICTION_MISSING_KYC_FROM = uint8(0x01);
    uint8 internal constant _RESTRICTION_MISSING_KYC_TO   = uint8(0x02);

    function detectTransferRestriction(address from, address to, uint256)
    public view override returns (uint8)
    {
        // Allow non kyc to withdraw
        // if (to == address(0)) return _RESTRICTION_OK;

        // sender must be whitelisted or mint
        if (from != address(0) && !isKYC(from))
        {
            return _RESTRICTION_MISSING_KYC_FROM;
        }
        // receiver must be whitelisted or burn
        if (to != address(0) && !isKYC(to))
        {
            return _RESTRICTION_MISSING_KYC_TO;
        }
        return _RESTRICTION_OK;
    }

    function messageForTransferRestriction(uint8 restrictionCode)
    public view override returns (string memory)
    {
        if (restrictionCode == _RESTRICTION_MISSING_KYC_FROM)
        {
            return "Sender is missing KYC";
        }
        if (restrictionCode == _RESTRICTION_MISSING_KYC_TO)
        {
            return "Receiver is missing KYC";
        }
        revert("invalid-restriction-code");
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
    internal virtual override
    {
        uint8 restrictionCode = detectTransferRestriction(from, to, amount);
        if (restrictionCode != _RESTRICTION_OK)
        {
            revert(messageForTransferRestriction(restrictionCode));
        }
        super._beforeTokenTransfer(from, to, amount);
    }
}
