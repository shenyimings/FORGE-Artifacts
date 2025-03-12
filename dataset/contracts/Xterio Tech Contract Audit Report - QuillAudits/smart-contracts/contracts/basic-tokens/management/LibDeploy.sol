// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../BasicERC721.sol";
import "../BasicERC1155.sol";

function addrToString(address addr) pure returns (string memory) {
    bytes memory data = abi.encodePacked(addr);

    bytes memory alphabet = "0123456789abcdef";

    bytes memory str = new bytes(2 + data.length * 2);
    str[0] = "0";
    str[1] = "x";
    for (uint256 i = 0; i < data.length; i++) {
        str[2 + i * 2] = alphabet[uint256(uint8(data[i] >> 4))];
        str[3 + i * 2] = alphabet[uint256(uint8(data[i] & 0x0f))];
    }
    return string(str);
}

library LibDeployBasicERC721 {
    event DeployContract(
        address indexed deployer,
        address indexed deployedAddress,
        bool indexed isERC721
    );

    function deployBasicERC721OperatorFilterer(
        string calldata _name,
        string calldata _symbol,
        string calldata _baseURI,
        address subscriptionOrRegistrantToCopy,
        bool subscribe,
        uint256 _salt,
        address gatewayAddress
    ) external returns (address deployedAddress) {
        // Deploy the contract and set its gateway.
        deployedAddress = address(
            new BasicERC721{salt: bytes32(_salt)}(
                msg.sender,
                _name,
                _symbol,
                _baseURI,
                subscriptionOrRegistrantToCopy,
                subscribe,
                gatewayAddress
            )
        );

        emit DeployContract(msg.sender, deployedAddress, true);

        // Grant this contract temporary permission to call `ERC721_setURI`
        IGateway(gatewayAddress).setManagerOf(deployedAddress, address(this));

        // Set uri of the newly deployed contract.
        IGateway(gatewayAddress).ERC721_setURI(
            deployedAddress,
            string(
                abi.encodePacked(_baseURI, addrToString(deployedAddress), "/")
            )
        );

        // Set manager of the newly deployed contract.
        IGateway(gatewayAddress).setManagerOf(deployedAddress, msg.sender);
    }
}

library LibDeployBasicERC1155 {
    event DeployContract(
        address indexed deployer,
        address indexed deployedAddress,
        bool indexed isERC721
    );

    function deployBasicERC1155OperatorFilterer(
        string calldata _baseURI,
        address subscriptionOrRegistrantToCopy,
        bool subscribe,
        uint256 _salt,
        address gatewayAddress
    ) public returns (address deployedAddress) {
        // Deploy the contract and set its gateway.
        deployedAddress = address(
            new BasicERC1155{salt: bytes32(_salt)}(
                msg.sender,
                _baseURI,
                subscriptionOrRegistrantToCopy,
                subscribe,
                gatewayAddress
            )
        );

        emit DeployContract(msg.sender, deployedAddress, false);

        // Grant this contract temporary permission to call `ERC1155_setURI`
        IGateway(gatewayAddress).setManagerOf(deployedAddress, address(this));

        // Set uri of the newly deployed contract.
        IGateway(gatewayAddress).ERC1155_setURI(
            deployedAddress,
            string(
                abi.encodePacked(_baseURI, addrToString(deployedAddress), "/")
            )
        );

        // Set manager of the newly deployed contract.
        IGateway(gatewayAddress).setManagerOf(deployedAddress, msg.sender);
    }
}
