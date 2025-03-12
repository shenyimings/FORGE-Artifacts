// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

interface IPausable {
    function paused() external view returns (bool);
}
