pragma solidity =0.6.12;

interface xVempInterface {
    function balanceOf(address account) external view returns (uint256);
    function getPriorVotes(address account, uint blockNumber) external view returns (uint96);
}