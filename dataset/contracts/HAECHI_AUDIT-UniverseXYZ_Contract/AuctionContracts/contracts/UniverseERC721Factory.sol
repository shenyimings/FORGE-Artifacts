// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./UniverseERC721.sol";

contract UniverseERC721Factory is Ownable {
    address[] public deployedContracts;
    address public lastDeployedContractAddress;

    event LogUniverseERC721ContractDeployed(
        string tokenName,
        string tokenSymbol,
        address contractAddress,
        address owner,
        uint256 time
    );

    constructor() {}

    function deployUniverseERC721(string memory tokenName, string memory tokenSymbol)
        external
        returns (address universeERC721Contract)
    {
        UniverseERC721 deployedContract = new UniverseERC721(tokenName, tokenSymbol);

        deployedContract.transferOwnership(msg.sender);
        address deployedContractAddress = address(deployedContract);
        deployedContracts.push(deployedContractAddress);
        lastDeployedContractAddress = deployedContractAddress;

        emit LogUniverseERC721ContractDeployed(
            tokenName,
            tokenSymbol,
            deployedContractAddress,
            msg.sender,
            block.timestamp
        );

        return deployedContractAddress;
    }

    function getDeployedContractsCount() external view returns (uint256 count) {
        return deployedContracts.length;
    }
}
