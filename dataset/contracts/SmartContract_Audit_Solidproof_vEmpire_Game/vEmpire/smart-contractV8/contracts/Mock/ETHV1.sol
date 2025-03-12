// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

contract ETHV1 {
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardETHDebt; // Reward debt in ETH.
    }

    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;

    constructor() {}

    //to recieve ETH from admin
    receive() external payable {}

    // Deposit LP tokens to MasterChef for VEMP allocation.
    function deposit(uint256 _amount) public payable {
        require(msg.value == _amount, "Eth must be equal to staked amount");
        UserInfo storage user = userInfo[msg.sender];

        user.amount = user.amount + msg.value;
        user.rewardDebt = 0;
        user.rewardETHDebt = 0;
    }
}
