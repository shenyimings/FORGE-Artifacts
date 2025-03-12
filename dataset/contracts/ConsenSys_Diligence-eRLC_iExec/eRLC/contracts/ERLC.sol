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

import "@openzeppelin/contracts/token/ERC20/ERC20Snapshot.sol";
import "./Claimable.sol";
import "./ERC20KYC.sol";
import "./ERC20Softcap.sol";
import "./ERC677.sol";


abstract contract ERLC is ERC20KYC, ERC20Softcap, ERC20Snapshot, ERC677, Claimable
{
    constructor(string memory name, string memory symbol, uint256 softcap, address[] memory admins, address[] memory kycadmins)
    internal
    ERC20(name, symbol)
    ERC20Softcap(softcap)
    KYC(admins, kycadmins)
    {}

    /*************************************************************************
     *                       Administrative operations                       *
     *************************************************************************/
    function claim(address token, address to)
    public virtual
    onlyRole(DEFAULT_ADMIN_ROLE, _msgSender(), "restricted-to-admin")
    {
        _claim(token, to);
    }

    function snapshot()
    public virtual
    onlyRole(DEFAULT_ADMIN_ROLE, _msgSender(), "restricted-to-admin")
    returns (uint256)
    {
        return _snapshot();
    }

    /*************************************************************************
     *                         Overloaded operations                         *
     *************************************************************************/
    function _beforeTokenTransfer(address from, address to, uint256 amount)
    internal virtual override(ERC20, ERC20Snapshot, ERC20KYC)
    {
        ERC20Snapshot._beforeTokenTransfer(from, to, amount);
        ERC20KYC._beforeTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount)
    internal virtual override(ERC20, ERC20Softcap)
    {
        ERC20Softcap._mint(account, amount);
    }
}
