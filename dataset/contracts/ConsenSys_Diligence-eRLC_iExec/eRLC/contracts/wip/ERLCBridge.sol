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


contract ERLCBridge is ERLC
{
    address public bridgeContract;

    constructor(string memory name, string memory symbol, uint8 decimals, uint256 softcap, address[] memory admins, address[] memory kycadmins)
    public
    ERLC(name, symbol, softcap, admins, kycadmins)
    {
        _setupDecimals(decimals);
    }

    function setBridgeContract(address bridgecontract)
    external
    onlyRole(DEFAULT_ADMIN_ROLE, _msgSender(), "only-admin")
    {
        bridgeContract = bridgecontract;
    }

    /*************************************************************************
     *           Overload ERC20 transfer to enforce call to bridge           *
     *************************************************************************/
    function transfer(address recipient, uint256 amount)
    public virtual override returns (bool)
    {
        require(super.transfer(recipient, amount));
        if (recipient == bridgeContract)
        {
            require(IERC677Receiver(recipient).onTokenTransfer(_msgSender(), amount, new bytes(0)), "transfer-refused-by-bridge");
        }
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount)
    public virtual override returns (bool)
    {
        require(super.transferFrom(sender, recipient, amount));
        if (recipient == bridgeContract)
        {
            require(IERC677Receiver(recipient).onTokenTransfer(sender, amount, new bytes(0)), "transfer-refused-by-bridge");
        }
        return true;
    }

    /*************************************************************************
     *                          Mintable - Burnable                          *
     *************************************************************************/
    bytes32 public constant MINTER_ROLE  = keccak256("MINTER_ROLE");

    function isMinter(address account)
    public view returns (bool)
    {
        return hasRole(MINTER_ROLE, account);
    }

    function addMinter(address account)
    public virtual
    {
        grantRole(MINTER_ROLE, account);
    }

    function renounceMinter()
    public virtual
    {
        renounceRole(MINTER_ROLE, _msgSender());
    }

    function mint(address account, uint256 amount)
    public virtual
    onlyRole(MINTER_ROLE, _msgSender(), "restricted-to-admin")
    returns (bool)
    {
        _mint(account, amount);
        return true;
    }

    function burn(uint256 amount)
    public virtual
    {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount)
    public virtual
    {
        uint256 decreasedAllowance = allowance(account, _msgSender()).sub(amount, "ERC20: burn amount exceeds allowance");
        _approve(account, _msgSender(), decreasedAllowance);
        _burn(account, amount);
    }
}
