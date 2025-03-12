// SPDX-License-Identifier: proprietary
pragma solidity 0.8.19;

interface ISelfkeyStaking {

    event StakeAdded(address _account, uint _amount);
    event StakeWithdraw(address _account, uint _amount);
    event RewardsMinted(address _account, uint _amount);

    function lastTimeRewardApplicable() external view returns (uint);

    function rewardPerToken() external view returns (uint);

    function totalSupply() external view returns (uint);

    function stake(address _account, uint256 _amount, bytes32 _param, uint _timestamp, address _signer,bytes memory signature) external;

    function withdraw(uint amount) external;

    function earned(address _account) external view returns (uint);

    function notifyRewardMinted(address _account, uint _amount) external;

    function balanceOf(address account) external view returns (uint);
}
