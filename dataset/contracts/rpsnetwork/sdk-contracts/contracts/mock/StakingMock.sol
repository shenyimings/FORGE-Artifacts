pragma solidity 0.8.19;

contract StakingMock {
    mapping(address => uint256) public staked;

    function stakeFor(address user, uint256 amount) external payable {
        require(msg.value >= amount, "Insufficient staked value");
        staked[user] += amount;
    }
}