// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFakeTrusteeFee {
    function notifyReward(uint reward) external;
    function exit(address account) external;
    function enter(address account) external;
}

contract FakeTunnelBoringDAO {
    IFakeTrusteeFee public ftf;
    IERC20 public rewardToken;
    uint public trusteeCount;

    constructor(address _ftf, address _rewardToken) public {
        ftf = IFakeTrusteeFee(_ftf);
        rewardToken = IERC20(_rewardToken);
    }

    function notifyReward(uint reward) public {
        rewardToken.transfer(address(ftf), reward);
        ftf.notifyReward(reward);
    }

    function exit(address account) public {
        trusteeCount = trusteeCount - 1;
        ftf.exit(account);
    }

    function enter(address account) public {
        trusteeCount = trusteeCount + 1;
        ftf.enter(account);
    }

    function getRoleMemberCount(bytes32 role) external view returns (uint256) {
        return trusteeCount;
    }

}

contract FakeBoringDAO {

}