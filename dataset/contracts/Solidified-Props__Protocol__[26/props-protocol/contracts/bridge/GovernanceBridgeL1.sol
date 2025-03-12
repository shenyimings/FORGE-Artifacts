// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

import "../../fx-portal/contracts/tunnel/FxBaseRootTunnel.sol";

/**
 * @title  GovernanceBridgeL1
 * @author Props
 * @dev    This contract is responsible for handling governance actions coming from L2.
 */
contract GovernanceBridgeL1 is FxBaseRootTunnel {
    constructor(address _checkpointManager, address _fxRoot)
        FxBaseRootTunnel(_checkpointManager, _fxRoot)
    {}

    /**
     * @dev Handles governance actions relayed from L2 via the bridge.
     */
    function _processMessageFromChild(bytes memory _data) internal override {
        (address target, bytes memory callData) = abi.decode(_data, (address, bytes));
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = target.call(callData);
        require(success, "Transaction execution reverted");
    }
}
