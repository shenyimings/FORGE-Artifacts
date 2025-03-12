// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20.sol";

interface IKwenta is IERC20 {

    function mint(address account, uint amount) external;

    function burn(uint amount) external;

    function setSupplySchedule(address _supplySchedule) external;

}