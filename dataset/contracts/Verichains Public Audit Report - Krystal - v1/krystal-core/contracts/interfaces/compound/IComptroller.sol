pragma solidity 0.7.6;

import "./ICompErc20.sol";

interface IComptroller {
    function getAllMarkets() external view returns (ICompErc20[] memory);

    function getCompAddress() external view returns (address);

    function claimComp(
        address[] calldata holders,
        ICompErc20[] calldata cTokens,
        bool borrowers,
        bool suppliers
    ) external;

    function enterMarkets(address[] calldata cTokens) external returns (uint256[] memory);
}
