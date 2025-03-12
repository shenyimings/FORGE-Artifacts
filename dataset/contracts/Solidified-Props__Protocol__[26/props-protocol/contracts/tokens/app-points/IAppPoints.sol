// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

interface IAppPoints {
    function pause() external;

    function unpause() external;

    function updateTransferWhitelist(address _account, bool _status) external;
}
