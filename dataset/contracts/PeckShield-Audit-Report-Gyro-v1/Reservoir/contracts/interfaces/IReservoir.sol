pragma solidity ^0.7.5;

interface IReservoir {
    function bondDeposit(uint256 amount, uint256 profit) external returns (uint256);

    function deposit(
        address tokenIn,
        uint256 amount,
        uint256 profit
    ) external returns (uint256);

    function mintRewards(address recipient, uint256 amount) external returns (uint256);
}
