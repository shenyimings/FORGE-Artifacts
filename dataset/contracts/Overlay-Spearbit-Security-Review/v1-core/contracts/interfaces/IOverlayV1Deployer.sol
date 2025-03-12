// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../libraries/Risk.sol";

interface IOverlayV1Deployer {
    function factory() external view returns (address);

    function deploy(
        address ovl,
        address feed,
        Risk.Params memory params
    ) external returns (address);
}
