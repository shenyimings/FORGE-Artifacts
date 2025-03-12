//SPDX-License-Identifier: CC-BY-NC-ND-4.0
pragma solidity 0.8.7;

/// @title The price observer interface
interface IPriceObserver {
    /**
     * @notice Indicates that the privileged writer has changed
     * @param writer Address of the new privileged writer
     */
    event WriterChanged(address indexed writer);

    function capacity() external view returns (uint256);

    function length() external view returns (uint256);

    function get(uint256 i) external view returns (int256);

    function getAll() external view returns (int256[24] memory);

    function add(int256 x) external returns (bool);
}
