// SPDX-License-Identifier: MIT
pragma solidity >=0.7.2;

interface IRibbonFactory {
    function isInstrument(address instrument) external returns (bool);

    function getAdapter(string calldata protocolName)
        external
        view
        returns (address);

    function getAdapters()
        external
        view
        returns (address[] memory adaptersArray);

    function burnGasTokens() external;
}
