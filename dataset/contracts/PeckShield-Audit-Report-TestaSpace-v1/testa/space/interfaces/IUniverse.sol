pragma solidity 0.5.16;

interface IUniverse {
    function depositETH() external payable;
    function getHQBase() external view returns (address);
    function getUniverseShare() external view returns (uint256);
    function getPlanetETHShare() external view returns (uint256);
    function getHQBaseShare() external view returns (uint256);
    function getRefferral() external view returns (address payable);
}