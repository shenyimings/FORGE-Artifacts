// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.6.0;

import "../interfaces/IWithdrawalDelayer.sol";

contract PayableRevert {
    bool public paymentEnable = true;

    function disablePayment() public {
        paymentEnable = false;
    }

    function enablePayment() public {
        paymentEnable = true;
    }

    fallback() external payable {
        require(paymentEnable, "Not payable");
    }

    receive() external payable {
        require(paymentEnable, "Not payable");
    }

    function transferEmergencyCouncil(
        address withdrawalDelayerAddress,
        address payable newEmergencyCouncil
    ) public {
        IWithdrawalDelayer(withdrawalDelayerAddress).transferEmergencyCouncil(
            newEmergencyCouncil
        );
    }

    function transferGovernance(
        address withdrawalDelayerAddress,
        address newAddress
    ) public {
        IWithdrawalDelayer(withdrawalDelayerAddress).transferGovernance(
            newAddress
        );
    }

    function enableEmergencyMode(address withdrawalDelayerAddress) public {
        IWithdrawalDelayer(withdrawalDelayerAddress).enableEmergencyMode();
    }

    function changeWithdrawalDelay(
        address withdrawalDelayerAddress,
        uint64 _newWithdrawalDelay
    ) public {
        IWithdrawalDelayer(withdrawalDelayerAddress).changeWithdrawalDelay(
            _newWithdrawalDelay
        );
    }

    function escapeHatchWithdrawal(
        address withdrawalDelayerAddress,
        address _to,
        address _token,
        uint256 _amount
    ) public {
        IWithdrawalDelayer(withdrawalDelayerAddress).escapeHatchWithdrawal(
            _to,
            _token,
            _amount
        );
    }
}
