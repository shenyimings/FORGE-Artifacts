//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

interface IFirewall {
    function setGovernor(address newGovernor) external;
    function setExecutor(address newExecutor) external;
    function allowExecutor(bytes4 functionSelector, bool executorCanCall_) external;
    fallback() external payable;
    receive() external payable;
}
