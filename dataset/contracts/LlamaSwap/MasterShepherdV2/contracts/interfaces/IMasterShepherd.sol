// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

interface IMasterShepherd {
    function lamaPerBlock() external view returns (uint256);

    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function setDevAddress(address _devaddr) external;
}