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

import "./interfaces/IERC677.sol";
import "./ERLC.sol";


contract ERLCTokenSwap is ERLC, IERC677Receiver
{
    IERC20 public immutable underlyingToken;

    constructor(
        address          underlyingtoken,
        string    memory name,
        string    memory symbol,
        uint256          softcap,
        address[] memory admins,
        address[] memory kycadmins)
    public
    ERLC(name, symbol, softcap, admins, kycadmins)
    {
        underlyingToken = IERC20(underlyingtoken);
        _setupDecimals(ERC20(underlyingtoken).decimals());
    }

    /*************************************************************************
     *                       Escrow - public interface                       *
     *************************************************************************/
    function deposit(uint256 amount)
    public
    {
        _deposit(_msgSender(), amount);
        _mint(_msgSender(), amount);
    }

    function withdraw(uint256 amount)
    public
    {
        _burn(_msgSender(), amount);
        _withdraw(_msgSender(), amount);
    }

    function recover()
    public
    onlyRole(DEFAULT_ADMIN_ROLE, _msgSender(), "only-admin")
    {
        _mint(_msgSender(), SafeMath.sub(underlyingToken.balanceOf(address(this)), totalSupply()));
    }

    function claim(address token, address to)
    public virtual override
    onlyRole(DEFAULT_ADMIN_ROLE, _msgSender(), "only-admin")
    {
        require(token != address(underlyingToken), "cannot-claim-underlying-token");
        super.claim(token, to);
    }

    /*************************************************************************
     *            ERC677Receiver - One-transaction ERC20 deposits            *
     *************************************************************************/
    function receiveApproval(address sender, uint256 amount, address token, bytes calldata)
    public override returns (bool)
    {
        require(token == address(underlyingToken), "wrong-token");
        _deposit(sender, amount);
        _mint(sender, amount);
        return true;
    }

    function onTokenTransfer(address sender, uint256 amount, bytes calldata)
    public override returns (bool)
    {
        require(_msgSender() == address(underlyingToken), "wrong-sender");
        _mint(sender, amount);
        return true;
    }

    /*************************************************************************
     *                      Escrow - internal functions                      *
     *************************************************************************/
    function _deposit(address from, uint256 amount)
    internal
    {
        require(underlyingToken.transferFrom(from, address(this), amount), "failed-transferFrom");
    }

    function _withdraw(address to, uint256 amount)
    internal
    {
        require(underlyingToken.transfer(to, amount), "failed-transfer");
    }
}
