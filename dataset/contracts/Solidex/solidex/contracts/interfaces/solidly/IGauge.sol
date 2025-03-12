pragma solidity 0.8.11;

interface IGauge {
    function deposit(uint amount, uint tokenId) external;
    function withdraw(uint amount) external;
    function getReward(address account, address[] memory tokens) external;
    function earned(address token, address account) external view returns (uint256);
}
