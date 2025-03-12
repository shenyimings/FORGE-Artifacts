pragma solidity 0.8.11;

interface IBribe {
    function getReward(uint tokenId, address[] memory tokens) external;
}
