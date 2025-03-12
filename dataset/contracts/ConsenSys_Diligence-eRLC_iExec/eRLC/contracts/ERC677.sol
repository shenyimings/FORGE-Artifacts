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
import "./interfaces/IERC677.sol";
import "./interfaces/IERC677Receiver.sol";


abstract contract ERC677 is IERC677, ERC20
{
    function approveAndCall(address spender, uint256 amount, bytes calldata extraData)
    external virtual override returns (bool)
    {
        approve(spender, amount);
        require(IERC677Receiver(spender).receiveApproval(_msgSender(), amount, address(this), extraData), "approval-refused-by-receiver");
        return true;
    }

    function transferAndCall(address receiver, uint256 amount, bytes calldata data)
    external virtual override returns (bool)
    {
        transfer(receiver, amount);
        require(IERC677Receiver(receiver).onTokenTransfer(_msgSender(), amount, data), "transfer-refused-by-receiver");
        return true;
    }
}
