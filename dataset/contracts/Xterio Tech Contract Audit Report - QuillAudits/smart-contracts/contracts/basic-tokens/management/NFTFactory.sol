// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interfaces/IGateway.sol";
import "../BasicERC721.sol";
import "../BasicERC1155.sol";
import "./LibDeploy.sol";

contract NFTFactory {
    address public gatewayAddress;

    event DeployContract(
        address indexed deployer,
        address indexed deployedAddress,
        bool indexed isERC721
    );

    constructor(address _gatewayAddress) {
        gatewayAddress = _gatewayAddress;
    }

    function deployBasicERC721(
        string calldata _name,
        string calldata _symbol,
        string calldata _baseURI,
        uint256 _salt
    ) external returns (address deployedAddress) {
        return
            deployBasicERC721OperatorFilterer(
                _name,
                _symbol,
                _baseURI,
                address(0),
                false,
                _salt
            );
    }

    /**
     * Deploy a BasicERC721 contract.
     */
    function deployBasicERC721OperatorFilterer(
        string calldata _name,
        string calldata _symbol,
        string calldata _baseURI,
        address subscriptionOrRegistrantToCopy,
        bool subscribe,
        uint256 _salt
    ) public returns (address deployedAddress) {
        return
            LibDeployBasicERC721.deployBasicERC721OperatorFilterer(
                _name,
                _symbol,
                _baseURI,
                subscriptionOrRegistrantToCopy,
                subscribe,
                _salt,
                gatewayAddress
            );
    }

    function deployBasicERC1155(string calldata _baseURI, uint256 _salt)
        external
        returns (address deployedAddress)
    {
        return
            deployBasicERC1155OperatorFilterer(
                _baseURI,
                address(0),
                false,
                _salt
            );
    }

    /**
     * Deploy a BasicERC1155 contract.
     */
    function deployBasicERC1155OperatorFilterer(
        string calldata _baseURI,
        address subscriptionOrRegistrantToCopy,
        bool subscribe,
        uint256 _salt
    ) public returns (address deployedAddress) {
        return
            LibDeployBasicERC1155.deployBasicERC1155OperatorFilterer(
                _baseURI,
                subscriptionOrRegistrantToCopy,
                subscribe,
                _salt,
                gatewayAddress
            );
    }
}
