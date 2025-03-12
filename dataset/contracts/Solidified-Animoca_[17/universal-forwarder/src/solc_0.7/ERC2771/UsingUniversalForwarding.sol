// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./UsingAppendedCallData.sol";
import "./IERC2771.sol";
import "./IForwarderRegistry.sol";

abstract contract UsingUniversalForwarding is UsingAppendedCallData, IERC2771 {
    IForwarderRegistry internal immutable _forwarderRegistry;
    address internal immutable _universalForwarder;

    constructor(IForwarderRegistry forwarderRegistry, address universalForwarder) {
        _universalForwarder = universalForwarder;
        _forwarderRegistry = forwarderRegistry;
    }

    function isTrustedForwarder(address forwarder) external view virtual override returns (bool) {
        return forwarder == _universalForwarder || forwarder == address(_forwarderRegistry);
    }

    function _msgSender() internal view virtual returns (address payable) {
        address payable msgSender = msg.sender;
        address payable sender = _lastAppendedDataAsSender();
        if (msgSender == address(_forwarderRegistry) || msgSender == _universalForwarder) {
            // if forwarder use appended data
            return sender;
        }

        // if msg.sender is neither the registry nor the universal forwarder,
        // we have to check the last 20bytes of the call data intepreted as an address
        // and check if the msg.sender was registered as forewarder for that address
        // we check tx.origin to save gas in case where msg.sender == tx.origin
        // solhint-disable-next-line avoid-tx-origin
        if (msgSender != tx.origin && _forwarderRegistry.isForwarderFor(sender, msgSender)) {
            return sender;
        }

        return msgSender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        address payable msgSender = msg.sender;
        if (msgSender == address(_forwarderRegistry) || msgSender == _universalForwarder) {
            // if forwarder use appended data
            return _msgDataAssuming20BytesAppendedData();
        }

        // we check tx.origin to save gas in case where msg.sender == tx.origin
        // solhint-disable-next-line avoid-tx-origin
        if (msgSender != tx.origin && _forwarderRegistry.isForwarderFor(_lastAppendedDataAsSender(), msgSender)) {
            return _msgDataAssuming20BytesAppendedData();
        }
        return msg.data;
    }
}
