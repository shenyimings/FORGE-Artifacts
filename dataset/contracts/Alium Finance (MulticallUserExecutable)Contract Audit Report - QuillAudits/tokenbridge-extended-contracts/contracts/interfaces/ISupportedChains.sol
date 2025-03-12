// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISupportedChains {
    function addChain(uint256 _chainId) external;

    function removeChain(uint256 _chainId) external;

    function getChainStatus(uint256 _chainId)
        external
        view
        returns (bool status);

    function getSupportedChains()
        external
        view
        returns (uint256[] memory chains);

    function chainLength() external view returns (uint256 length);
}
