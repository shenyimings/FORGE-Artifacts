// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IBasisAsset {
    function decimals() external view returns (uint8);

    function cap() external view returns (uint256);

    function mint(address, uint256) external;

    function burn(uint256) external;

    function burnFrom(address, uint256) external;

    function isOperator() external returns (bool);

    function operator() external view returns (address);

    function transferOperator(address newOperator_) external;

    function transferOwnership(address newOwner_) external;
}
