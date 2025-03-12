// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "../interfaces/ICallDelegator.sol";

contract MockCallDelegator is ICallDelegator {
    bool private canCall;

    /**
     * @inheritdoc ICallDelegator
     */
    function canCallOn(address caller, address vault) external view override returns (bool) {
        require(caller != vault, "Invalid vault");
        return canCall;
    }

    function setCanCall(bool _canCall) external {
        canCall = _canCall;
    }
}
