// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IOwnable {
    function owner() external view returns (address);

    function renounceOwnership() external;

    function transferOwnership(address newOwner_) external;
}
