// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "kresko-lib/token/IERC20.sol";

contract SDICoverRecipient {
    address public owner;
    address public pendingOwner;

    constructor(address _owner) {
        owner = _owner;
    }

    function withdraw(address token, address recipient, uint256 amount) external {
        require(msg.sender == owner, "not-owner");
        require(recipient.code.length != 0, "recipient-eoa");
        if (address(token) == address(0)) payable(recipient).transfer(amount);
        else IERC20(token).transfer(recipient, amount);
    }

    function changeOwner(address _owner) external {
        require(msg.sender == owner, "not-owner");
        pendingOwner = _owner;
    }

    function acceptOwnership(address _owner) external {
        require(msg.sender == pendingOwner, "not-pending-owner");
        owner = _owner;
        pendingOwner = address(0);
    }
}
