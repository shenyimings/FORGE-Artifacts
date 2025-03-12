// SPDX-License-Identifier: AGPL-3.0-only

/*
    DistributorMock.sol - SKALE Allocator
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

import "@openzeppelin/contracts-ethereum-package/contracts/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";

import "../interfaces/delegation/IDistributor.sol";



contract DistributorMock is IDistributor, IERC777Recipient {    

    IERC1820Registry private _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    IERC20 public skaleToken;

    //        wallet =>   validatorId => tokens
    mapping (address => mapping (uint256 => uint)) public approved;

    constructor (address skaleTokenAddress) public {        
        skaleToken = IERC20(skaleTokenAddress);
        _erc1820.setInterfaceImplementer(address(this), keccak256("ERC777TokensRecipient"), address(this));
    }

    function withdrawBounty(uint256 validatorId, address to) external override {
        uint256 bounty = approved[msg.sender][validatorId];        
        delete approved[msg.sender][validatorId];
        require(skaleToken.transfer(to, bounty), "Failed to transfer tokens");
    }

    function tokensReceived(
        address,
        address,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata
    )
        external override
    {
        require(to == address(this), "Receiver is incorrect");
        require(userData.length == 32 * 2, "Data length is incorrect");
        (uint256 validatorId, address wallet) = abi.decode(userData, (uint, address));
        _payBounty(wallet, validatorId, amount);
    }

    // private

    function _payBounty(address wallet, uint256 validatorId, uint256 amount) private {
        approved[wallet][validatorId] += amount;
    }
}