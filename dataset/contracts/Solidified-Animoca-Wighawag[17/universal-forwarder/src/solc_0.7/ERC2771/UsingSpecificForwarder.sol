// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./IERC2771.sol";
import "./UsingAppendedCallData.sol";

abstract contract UsingSpecificForwarder is UsingAppendedCallData, IERC2771 {
    address internal immutable _forwarder;

    constructor(address forwarder) {
        _forwarder = forwarder;
    }

    function isTrustedForwarder(address forwarder) external view virtual override returns (bool) {
        return forwarder == _forwarder;
    }

    function _msgSender() internal view virtual returns (address payable result) {
        if (msg.sender == _forwarder) {
            return _lastAppendedDataAsSender();
        }
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        if (msg.sender == _forwarder) {
            return _msgDataAssuming20BytesAppendedData();
        }
        return msg.data;
    }
}
