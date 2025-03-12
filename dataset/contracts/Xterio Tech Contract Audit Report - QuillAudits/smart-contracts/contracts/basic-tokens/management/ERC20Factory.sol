// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interfaces/IGateway.sol";
import "../BasicERC20.sol";
import "../BasicERC20Capped.sol";

contract ERC20Factory {
    address public gatewayAddress;

    event DeployContract(
        address indexed deployer,
        address indexed deployedAddress,
        bool indexed capped
    );

    constructor(address _gatewayAddress) {
        gatewayAddress = _gatewayAddress;
    }

    /**
     * Deploy a BasicERC20 contract.
     */
    function deployBasicERC20(
        string calldata _name,
        string calldata _symbol,
        uint8 _decimals,
        uint256 _salt
    ) external returns (address deployedAddress) {
        deployedAddress = address(
            new BasicERC20{salt: bytes32(_salt)}(
                _name,
                _symbol,
                _decimals,
                gatewayAddress
            )
        );

        emit DeployContract(msg.sender, deployedAddress, false);

        // Set manager of the newly deployed contract.
        IGateway(gatewayAddress).setManagerOf(deployedAddress, msg.sender);
    }

    /**
     * Deploy a BasicERC20 contract.
     * @param _cap The upperbound of the total token supply.
     */
    function deployBasicERC20Capped(
        string calldata _name,
        string calldata _symbol,
        uint8 _decimals,
        uint256 _cap,
        uint256 _salt
    ) external returns (address deployedAddress) {
        require(_cap > 0, "ERC20Factory: invalid cap");

        deployedAddress = address(
            new BasicERC20Capped{salt: bytes32(_salt)}(
                _name,
                _symbol,
                _decimals,
                _cap,
                gatewayAddress
            )
        );

        emit DeployContract(msg.sender, deployedAddress, true);

        // Set manager of the newly deployed contract.
        IGateway(gatewayAddress).setManagerOf(deployedAddress, msg.sender);
    }
}
