// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IDkimVerifier {
    function from(bytes memory data) external view returns (bytes memory);

    function subject(bytes memory data) external view returns (bytes memory);

    function hash(bytes memory data) external view returns (bytes32);

    function verify(
        bytes32 server,
        bytes calldata data,
        bytes calldata signature
    ) external view returns (bool);
}
