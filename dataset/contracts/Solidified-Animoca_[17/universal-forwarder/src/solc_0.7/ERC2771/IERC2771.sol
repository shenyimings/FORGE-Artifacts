// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface IERC2771 {
    function isTrustedForwarder(address forwarder) external view returns (bool);
}
