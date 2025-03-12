// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IYieldModule.sol";

interface ISmartFarmooor {

    struct YieldModuleDetails {
        IYieldModule module;
        uint allocation;
    }

    /** admin **/

    function addModule(IYieldModule _module) external;
    function setModuleAllocation(uint[] memory _allocation) external;
    function panic() external payable;
    function finishPanic() external;

    /** user **/

    function deposit(uint256 amountToken) external;
    function withdraw(uint256 shares) external payable returns(uint256 instant, uint256 async);
    function harvest() external returns (uint256);

    /** view **/

    // variables
    function feeManager() external returns (address);
    function baseToken() external returns (address);
    function minHarvestThreshold() external returns (uint256);
    function numberOfModules() external returns (uint256);
    function balanceSnapshot() external returns (uint256);
    function performanceFee() external returns (uint16);
    function cap() external returns (uint256);
    function yieldOptions(uint key) view external returns (IYieldModule, uint);

    // getters
    function pricePerShare() external returns (uint);
    function lastUpdatedPricePerShare() external view returns (uint);
    function getExecutionFee(uint _amount) external view returns (uint256);
    function getModulesBalance() external returns (uint256);
    function getLastUpdatedModulesBalance() external view returns (uint256);
    function getImplementation() external view returns (address);
}