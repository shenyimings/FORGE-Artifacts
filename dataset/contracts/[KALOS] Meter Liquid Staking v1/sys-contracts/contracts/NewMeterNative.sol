pragma solidity ^0.8.0;

import "./IMeterNative.sol";

contract NewMeterNative is IMeterNative {
    constructor () payable {}
    
    // MTR related
    function native_mtr_totalSupply() public pure returns(uint256) {  }
    function native_mtr_totalBurned() public pure returns(uint256) {  }
    function native_mtr_get(address addr) public pure returns(uint256) {  }
    function native_mtr_add(address addr, uint256 amount) public {
        emit MeterTrackerEvent(addr, amount, "native_mtr_add");
        return;
    }
    function native_mtr_sub(address addr, uint256 amount) public returns(bool) {
        emit MeterTrackerEvent(addr, amount, "native_mtr_sub");
        return true;    
    }

    // deprecated
    function native_mtr_locked_get(address addr) public pure returns(uint256) {  }
    function native_mtr_locked_add(address addr, uint256 amount) public {
        emit MeterTrackerEvent(addr, amount, "native_mtr_locked_add");
        return;
    }
    function native_mtr_locked_sub(address addr, uint256 amount) public returns(bool) {
        emit MeterTrackerEvent(addr, amount, "native_mtr_locked_sub");
        return true;    
    }

    // MTRG related
    function native_mtrg_totalSupply() public pure returns(uint256) {  }
    function native_mtrg_totalBurned() public pure returns(uint256) {  }
    function native_mtrg_get(address addr) public pure returns(uint256) {  }
    function native_mtrg_add(address addr, uint256 amount) public {
        emit MeterTrackerEvent(addr, amount, "native_mtrg_add");
        return;
    }
    function native_mtrg_sub(address addr, uint256 amount) public returns(bool) {
        emit MeterTrackerEvent(addr, amount, "native_mtrg_sub");
        return true;    
    }
    function native_mtrg_locked_get(address addr) public pure returns(uint256) { }

    // deprecated
    function native_mtrg_locked_add(address addr, uint256 amount) public {
        emit MeterTrackerEvent(addr, amount, "native_mtrg_locked_add");
        return;
    }
    function native_mtrg_locked_sub(address addr, uint256 amount) public returns(bool) {
        emit MeterTrackerEvent(addr, amount, "native_mtrg_locked_sub");
        return true;    
    }

    // master
    function native_master(address addr) public pure returns(address) { }
}

