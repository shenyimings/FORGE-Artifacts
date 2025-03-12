// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../interface/IYieldModule.sol";

interface IYieldModule {

    /** admin **/

    function setDex(address _dex) external;
    function setExecutionFee(uint256 _executionFee) external;
    function setRewards(address[] memory _rewards) external;
    function approveDex() external;

    /** manager **/

    function deposit(uint256 amount) external;
    function withdraw(uint256 shareFraction, address receiver) external payable returns(uint256 instant, uint256 pending);
    function harvest(address receiver) external returns(uint256);

    /** view **/

    // variables
    function smartFarmooor() external returns (address);
    function dex() external returns (address);
    function manager() external returns (address);
    function baseToken() external view returns(address);
    function executionFee() external view returns(uint256);
    function rewards(uint256 index) external view returns(address);
    function name() external view returns (string memory);

    // getters
    function getBalance() external returns(uint256);
    function getLastUpdatedBalance() external view returns(uint256);
    function getExecutionFee(uint256 amount) external view returns (uint256);
    function getImplementation() external view returns (address);

    /** events **/

    event Deposit(address token, uint256 amount);
    event Withdraw(address token, uint256 amount);
    event Harvest(address token, uint256 amount);
}
