// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../interfaces/IMinerHealthCheck.sol";
import "../helpers/RolesHandler.sol";
import "../libs/MinerTypes.sol";

/**
 * @title MinerList
 * @dev A smart contract for managing a list of miners.
 */
contract MinerList is Initializable, RolesHandler {
    /// @notice The address of the MinerHealthCheck contract
    IMinerHealthCheck public minerHealthCheck;
    /// @notice A mapping to store the list of miners by address and node type
    mapping(address => mapping(MinerTypes.NodeType => bool)) public list;
    /// @notice  A mapping to store the count of miners by node type
    mapping(MinerTypes.NodeType => uint256) public count;

    /// @notice new miner is added
    event AddMiner(
        address indexed minerAddress,
        MinerTypes.NodeType indexed nodeType
    );
    /// @notice miner is deleted
    event DeleteMiner(
        address indexed minerAddress,
        MinerTypes.NodeType indexed nodeType
    );

    /**
     * @dev Initializes the MinerList contract with the address of the MinerHealthCheck contract.
     * @param minerHealthCheckAddress The address of the MinerHealthCheck contract.
     */
    function initialize(address minerHealthCheckAddress) external initializer {
        require(
            minerHealthCheckAddress != address(0),
            "MinerList: cannot set zero address"
        );
        minerHealthCheck = IMinerHealthCheck(minerHealthCheckAddress);
    }

    /**
     * @dev Checks if an address is a miner of the specified node type.
     * @param minerAddress The address to check.
     * @param nodeType The type of miner node to check.
     * @return A boolean indicating whether the address is a miner.
     */
    function isMiner(
        address minerAddress,
        MinerTypes.NodeType nodeType
    ) external view returns (bool) {
        return list[minerAddress][nodeType];
    }

    /**
     * @dev Adds an address as a miner of the specified node type.
     * @param minerAddress The address to add as a miner.
     * @param nodeType The type of miner node to add.
     */
    function addMiner(
        address minerAddress,
        MinerTypes.NodeType nodeType
    ) external onlyManagerRole(msg.sender) {
        _addMiner(minerAddress, nodeType);
    }

    /**
     * @dev Deletes an address from the list of miners of the specified node type.
     * @param minerAddress The address to delete from the list of miners.
     * @param nodeType The type of miner node to delete from.
     */
    function deleteMiner(
        address minerAddress,
        MinerTypes.NodeType nodeType
    ) external onlyManagerRole(msg.sender) {
        _deleteMiner(minerAddress, nodeType);
    }

    /**
     * @dev Internal function to add an address as a miner of the specified node type.
     * @param minerAddress The address to add as a miner.
     * @param nodeType The type of miner node to add.
     */
    function _addMiner(
        address minerAddress,
        MinerTypes.NodeType nodeType
    ) internal {
        list[minerAddress][nodeType] = true;
        count[nodeType]++;
        minerHealthCheck.manualPing(minerAddress, nodeType);

        emit AddMiner(minerAddress, nodeType);
    }

    /**
     * @dev Internal function to delete an address from the list of miners of the specified node type.
     * @param minerAddress The address to delete from the list of miners.
     * @param nodeType The type of miner node to delete from.
     */
    function _deleteMiner(
        address minerAddress,
        MinerTypes.NodeType nodeType
    ) internal {
        delete list[minerAddress][nodeType];
        count[nodeType]--;

        emit DeleteMiner(minerAddress, nodeType);
    }
}
