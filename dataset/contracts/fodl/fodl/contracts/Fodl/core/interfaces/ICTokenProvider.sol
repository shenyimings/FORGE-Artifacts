// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ICTokenProvider {
    function getCToken(address platform, address token) external view returns (address syntheticToken);
}
