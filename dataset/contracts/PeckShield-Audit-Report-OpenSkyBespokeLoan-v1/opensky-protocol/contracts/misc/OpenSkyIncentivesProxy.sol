// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import './UserProxies.sol';

abstract contract OpenSkyIncentivesProxy is UserProxies {
    function claimRewards(
        address incentivesController,
        address[] calldata assets,
        uint256 amount,
        address to
    ) external {
        require(address(userProxies[msg.sender]) != address(0), "HAS_NO_PROXY");
        bytes memory data = abi.encodeWithSignature("claimRewards(address[],uint256,address,bool)", assets, amount, to, false);
        userProxies[msg.sender].execute(address(incentivesController), data, 0);
    }
}
