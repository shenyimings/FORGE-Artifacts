pragma solidity ^0.8.3;

/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Hegic
 * Copyright (C) 2021 Hegic Protocol
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 **/

import "@opengsn/contracts/src/BaseRelayRecipient.sol";
import "@hegic/utils/contracts/Mocks/ERC20Mock.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @author 0mllwntrmt3
 * @title Hegic Protocol V8888 Exerciser Contract
 * @notice The contract that allows to automatically exercise options half an hour before expiration
 **/
contract Faucet is BaseRelayRecipient, Ownable {
    uint256 public ETHAmount = 0.2 ether;
    uint256 public pgUSDAmount = 10_000e6;
    ERC20Mock public immutable pgUSD;

    string public override versionRecipient = "2.2.5";

    constructor(ERC20Mock _pgUSD, address forwarder) {
        pgUSD = _pgUSD;
        _setTrustedForwarder(forwarder);
    }

    receive() external payable {}

    function _msgData()
        internal
        view
        virtual
        override(Context, BaseRelayRecipient)
        returns (bytes calldata)
    {
        return BaseRelayRecipient._msgData();
    }

    function _msgSender()
        internal
        view
        virtual
        override(Context, BaseRelayRecipient)
        returns (address)
    {
        return BaseRelayRecipient._msgSender();
    }

    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function get() external {
        pgUSD.mint(_msgSender(), pgUSDAmount);
        payable(_msgSender()).transfer(ETHAmount);
    }
}
