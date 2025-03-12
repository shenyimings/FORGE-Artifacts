pragma solidity ^0.8.0;

interface IMarket {

    function previewWrap(
        address asset,
        uint256 amount
    ) external view returns (uint256);

    function previewUnwrap(
        address asset,
        uint256 amount
    ) external view returns (uint256);

    function wrap(
        address asset,
        uint256 amount,
        address receiver
    ) external returns (uint256);

    function unwrap(
        address asset,
        uint256 amount,
        address receiver
    ) external returns (uint256);
}
