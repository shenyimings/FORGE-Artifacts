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


abstract contract ERC20Softcap is ERC20
{
    uint256 public immutable softCap;
    bool    public softCapReached;

    event SoftCapReached();

    constructor(uint256 softcap)
    internal
    {
        softCap        = softcap;
        softCapReached = false;
    }

    function _mint(address account, uint256 amount)
    internal virtual override
    {
        super._mint(account, amount);
        if (!softCapReached && totalSupply() >= softCap)
        {
            softCapReached = true;
            emit SoftCapReached();
        }
    }
}
