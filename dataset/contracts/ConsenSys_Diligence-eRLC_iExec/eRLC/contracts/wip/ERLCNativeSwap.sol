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

import "../interfaces/IERC677.sol";
import "../ERLC.sol";


contract ERLCNativeSwap is ERLC
{
    uint256 public ConversionRate;

    constructor(
        string    memory name,
        string    memory symbol,
        uint8            decimals,
        uint256          softcap,
        address[] memory admins,
        address[] memory kycadmins)
    public
    ERLC(name, symbol, softcap, admins, kycadmins)
    {
        ConversionRate = 10 ** SafeMath.sub(18, decimals);
        _setupDecimals(decimals);
    }

    /*************************************************************************
     *                       Escrow - public interface                       *
     *************************************************************************/
    receive()
    external payable
    {
        deposit();
    }

    function deposit()
    public payable
    {
        _mint(_msgSender(), msg.value.div(ConversionRate));
        Address.sendValue(_msgSender(), msg.value.mod(ConversionRate));
    }

    function withdraw(uint256 amount)
    public
    {
        _burn(_msgSender(), amount);
        Address.sendValue(_msgSender(), amount.mul(ConversionRate));
    }

    function recover()
    public
    onlyRole(DEFAULT_ADMIN_ROLE, _msgSender(), "only-admin")
    {
        uint256 delta = address(this).balance.sub(totalSupply().mul(ConversionRate));

        _mint(_msgSender(), delta.div(ConversionRate));
        Address.sendValue(_msgSender(), delta.mod(ConversionRate));
    }

    function claim(address token, address to)
    public virtual override
    onlyRole(DEFAULT_ADMIN_ROLE, _msgSender(), "only-admin")
    {
        super.claim(token, to);
    }
}
