pragma solidity ^0.5.16;

interface IStakeModifier {
    function getVotingPower(address user, uint256 votes) external view returns(uint256);
}
