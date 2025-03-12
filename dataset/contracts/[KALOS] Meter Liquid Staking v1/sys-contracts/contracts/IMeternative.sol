// SPDX-License-Identifier: MIT
// Copyright (c) 2018 The Meter.io developers

pragma solidity ^0.8.0;

interface IMeterNative {
    event MeterTrackerEvent(address _address, uint256 _amount, string _method);
    
    function native_mtr_totalSupply() external view returns (uint256);

    function native_mtr_totalBurned() external view returns (uint256);

    function native_mtr_get(address addr) external view returns (uint256);

    function native_mtr_add(address addr, uint256 amount) external;

    function native_mtr_sub(address addr, uint256 amount)
        external
        returns (bool);

    function native_mtr_locked_get(address addr)
        external
        view
        returns (uint256);

    function native_mtr_locked_add(address addr, uint256 amount) external;

    function native_mtr_locked_sub(address addr, uint256 amount)
        external
        returns (bool);

    //@@@@@
    function native_mtrg_totalSupply() external view returns (uint256);

    function native_mtrg_totalBurned() external view returns (uint256);

    function native_mtrg_get(address addr) external view returns (uint256);

    function native_mtrg_add(address addr, uint256 amount) external;

    function native_mtrg_sub(address addr, uint256 amount)
        external
        returns (bool);

    function native_mtrg_locked_get(address addr)
        external
        view
        returns (uint256);

    function native_mtrg_locked_add(address addr, uint256 amount) external;

    function native_mtrg_locked_sub(address addr, uint256 amount)
        external
        returns (bool);

    //@@@
    function native_master(address addr) external view returns (address);
}
