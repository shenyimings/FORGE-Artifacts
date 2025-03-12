pragma solidity 0.6.6;

// SPDX-License-Identifier: Unlicensed

import "./HodlDexV0.sol";

contract HodlDex is HodlDexV0 {
    
    function withdrawEth(uint amount) external override ifRunning {
        emit UserWithdrawEth(msg.sender, amount);
        balance.sub(ETH_ASSET, msg.sender, amount, 0);
        (bool success, /* bytes memory data */) = msg.sender.call{value:amount}("");
        require(success, "rejected by receiver");
    }
    
    function initResetUser(address userAddr) external override onlyMigration {
        emit UserUninitialized(msg.sender, userAddr);
        balance.add(HODL_ASSET, address(this), balance.balanceOf(HODL_ASSET, userAddr), 0);
        balance.sub(HODL_ASSET, userAddr, balance.balanceOf(HODL_ASSET, userAddr), 0);
        balance.sub(ETH_ASSET, userAddr, balance.balanceOf(ETH_ASSET, userAddr), 0);
        if(balance.balanceOf(ETH_ASSET, userAddr) > 0) {
            (bool success, /* bytes memory data */) = msg.sender.call{ value: balance.balanceOf(ETH_ASSET, userAddr) }("");
            require(success, "rejected by receiver");
        }
    }       
}