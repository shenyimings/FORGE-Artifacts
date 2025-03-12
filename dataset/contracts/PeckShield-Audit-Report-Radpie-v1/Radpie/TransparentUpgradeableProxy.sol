// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TransparentUpgradeableproxy is TransparentUpgradeableProxy {

    /**
     * @dev Initializes an upgradeable proxy managed by `_admin`, backed by the implementation at `_logic`, and
     * optionally initialized with `_data` as explained in {ERC1967Proxy-constructor}.
     */
    uint256 public timelockLength = 2 days;
    uint256 public timelockEndForUpgrade;
    uint256 public timelockEndForTimelock;
    uint256 public nextTimelock = 0;

    address public nextImplementation;

    constructor(
        address _logic,
        address admin_,
        bytes memory _data
    ) payable TransparentUpgradeableProxy(_logic, admin_, _data) {
    }

    function submitNewTimelock(uint256 _value) external ifAdmin {
        nextTimelock = _value;
        timelockEndForTimelock = block.timestamp + timelockLength;
    }

    function changeTimelock() external ifAdmin {
        require(nextTimelock != 0, "Cannot set timelock to 0");
        require(block.timestamp >= timelockEndForTimelock, "Timelock not ended");
        timelockLength = nextTimelock;
        nextTimelock = 0;
    }

    function submitUpgrade(address newImplementation) external ifAdmin {
        nextImplementation = newImplementation;
        timelockEndForUpgrade = block.timestamp + timelockLength;
    }    

}