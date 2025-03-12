// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

interface ISPropsToken {
    function mint(address dst, uint256 rawAmount) external;

    function burn(address src, uint256 rawAmount) external;

    function getCurrentVotes(address account) external view returns (uint96);

    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);

    function delegate(address delegatee) external;

    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
