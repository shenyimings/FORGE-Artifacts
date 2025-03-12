// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMasterChefContractor {
    function getMasterChef() external view returns (address);
    function getDepositFee(uint256 _pid) external view returns (uint256);
    function getLiquidity(uint256 _pid) external view returns (uint256);
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount, address sender) external;
    function emergencyWithdraw(uint256 _pid, uint256 _amount, address _sender) external;
}