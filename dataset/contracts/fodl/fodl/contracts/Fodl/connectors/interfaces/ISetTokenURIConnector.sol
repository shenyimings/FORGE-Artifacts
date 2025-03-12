// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ISetTokenURIConnector {
    function setTokenURI(
        string memory tokenURI,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
