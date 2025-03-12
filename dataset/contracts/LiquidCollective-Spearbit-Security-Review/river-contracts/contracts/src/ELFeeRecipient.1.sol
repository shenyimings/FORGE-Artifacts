//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./Initializable.sol";
import "./libraries/Errors.sol";
import "./libraries/LibOwnable.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/IELFeeRecipient.1.sol";

import "./state/shared/RiverAddress.sol";

/// @title Execution Layer Fee Recipient
/// @author Kiln
/// @notice This contract receives all the execution layer fees from the proposed blocks + bribes
contract ELFeeRecipientV1 is Initializable, IELFeeRecipientV1 {
    /// @notice Initialize the fee recipient with the required arguments
    /// @param _riverAddress Address of River
    function initELFeeRecipientV1(address _riverAddress) external init(0) {
        RiverAddress.set(_riverAddress);
    }

    /// @notice Pulls all the ETH to the River contract
    /// @dev Only callable by the River contract
    function pullELFees() external {
        address river = RiverAddress.get();
        if (msg.sender != river) {
            revert Errors.Unauthorized(msg.sender);
        }

        IRiverV1(payable(river)).sendELFees{value: address(this).balance}();
    }

    /// @notice Ether receiver
    receive() external payable {
        this;
    }

    /// @notice Invalid fallback detector
    fallback() external payable {
        revert InvalidCall();
    }
}
