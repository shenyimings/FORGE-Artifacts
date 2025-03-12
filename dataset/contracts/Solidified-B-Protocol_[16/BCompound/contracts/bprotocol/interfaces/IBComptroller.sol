pragma solidity 0.5.16;

interface IBComptroller {
    function isCToken(address cToken) external view returns (bool);
    function isBToken(address bToken) external view returns (bool);
    function c2b(address cToken) external view returns (address);
    function b2c(address bToken) external view returns (address);
}