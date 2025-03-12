// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

interface ITokenLockCheck {
    function isTransferLocked(address token, address account) external view returns (bool);
}
