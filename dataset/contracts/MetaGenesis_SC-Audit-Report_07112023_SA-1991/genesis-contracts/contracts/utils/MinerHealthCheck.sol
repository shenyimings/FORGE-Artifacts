// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../libs/MinerTypes.sol";
import "../interfaces/IMinerList.sol";
import "../interfaces/IMinerPool.sol";
import "../interfaces/IMetaPoints.sol";
import "../interfaces/IMinerFormulas.sol";
import "../helpers/RolesHandler.sol";

/**
 * @title MinerHealthCheck
 * @dev A smart contract for checking and managing miner health status.
 */
contract MinerHealthCheck is Initializable, RolesHandler {
    /// @notice Address of the MinerList contract
    IMinerList public minerList;
    /// @notice Address of the MinerFormulas contract
    IMinerFormulas public minerFormulas;
    /// @notice Address of the MinerPool contract
    IMinerPool public minerPool;
    /// @notice Address of the MetaPoints contract
    IMetaPoints public metaPoints;

    /// @notice The timeout duration for miner activity
    uint256 public timeout;

    /// @notice A mapping to store the last uptime of miners by address and node type
    mapping(address => mapping(MinerTypes.NodeType => uint256))
        public lastUptime;
    /// @notice A mapping to store the daily activities of nodes by date and node type
    mapping(uint256 => mapping(MinerTypes.NodeType => uint256))
        public dailyNodesActivities;
    /// @notice A mapping to store daily activities of nodes by date, address, and node type
    mapping(uint256 => mapping(address => mapping(MinerTypes.NodeType => uint256)))
        public dailyNodeActivity;

    /**
     * @dev Modifier to check if an address is a miner of the specified node type.
     * @param miner The address to check.
     * @param nodeType The type of miner node to check.
     */
    modifier isMiner(address miner, MinerTypes.NodeType nodeType) {
        require(
            minerList.isMiner(miner, nodeType),
            "MinerHealthCheck: Address is not miner"
        );
        _;
    }

    /**
     * @dev Initializes the MinerHealthCheck contract with required addresses and timeout.
     * @param minerListAddress The address of the MinerList contract.
     * @param minerFormulasAddress The address of the MinerFormulas contract.
     * @param minerPoolAddress The address of the MinerPool contract.
     * @param metaPointsAddress The address of the MetaPoints contract.
     * @param requiredTimeout The timeout duration for miner activity.
     */
    function initialize(
        address minerListAddress,
        address minerFormulasAddress,
        address minerPoolAddress,
        address metaPointsAddress,
        uint256 requiredTimeout
    ) external initializer {
        require(
            minerListAddress != address(0) &&
                minerFormulasAddress != address(0) &&
                minerPoolAddress != address(0) &&
                metaPointsAddress != address(0),
            "MinerHealthCheck: cannot set zero address"
        );
        require(
            requiredTimeout >= 14400,
            "MinerHealthCheck: requiredTimeout must be bigger than 4 hours in secs"
        );
        minerList = IMinerList(minerListAddress);
        minerFormulas = IMinerFormulas(minerFormulasAddress);
        minerPool = IMinerPool(minerPoolAddress);
        metaPoints = IMetaPoints(metaPointsAddress);
        timeout = requiredTimeout;
    }

    /**
     * @dev Pings a miner node to update its uptime and perform related actions.
     * @param nodeType The type of miner node to ping.
     * @return A boolean indicating whether the ping was successful.
     */
    function ping(
        MinerTypes.NodeType nodeType
    ) external isMiner(msg.sender, nodeType) returns (bool) {
        uint256 lastSeen = lastUptime[msg.sender][nodeType];
        uint256 maxLimit = lastSeen + timeout;

        if (maxLimit >= block.timestamp) {
            uint256 activityTime = block.timestamp - lastSeen;
            uint256 metaPointsReward = minerFormulas
                .calculateMetaPointsReward();
            metaPoints.mint(msg.sender, metaPointsReward * activityTime);
            _incrementDailyActiveTimes(msg.sender, nodeType, activityTime);
            _incrementDailyTotalActiveTimes(nodeType, activityTime);
            minerPool.claimMacroDailyReward(msg.sender, nodeType, activityTime);
        }

        lastUptime[msg.sender][nodeType] = block.timestamp;
        return true;
    }

    /**
     * @dev Checks the status of a miner node.
     * @param minerAddress The address of the miner node to check.
     * @param minerType The type of miner node to check.
     * @return A boolean indicating whether the miner node is active.
     */
    function status(
        address minerAddress,
        MinerTypes.NodeType minerType
    ) external view returns (bool) {
        return (
            (lastUptime[minerAddress][minerType] + timeout) >= block.timestamp
                ? true
                : false
        );
    }

    /**
     * @dev Sets a new timeout duration for miner activity.
     * @param newTimeout The new timeout duration to set.
     * @return A boolean indicating whether the operation was successful.
     */
    function setTimeout(
        uint256 newTimeout
    ) external onlyOwnerRole(msg.sender) returns (bool) {
        require(
            newTimeout >= 14400,
            "MinerHealthCheck: New timeout must be bigger than 4 hours in secs"
        );
        timeout = newTimeout;
        return (true);
    }

    /**
     * @dev Allows a manager to manually ping a miner node.
     * @param minerAddress The address of the miner node to ping.
     * @param nodeType The type of miner node to ping.
     */
    function manualPing(
        address minerAddress,
        MinerTypes.NodeType nodeType
    ) external isMiner(minerAddress, nodeType) onlyManagerRole(msg.sender) {
        lastUptime[minerAddress][nodeType] = block.timestamp;
    }

    /**
     * @dev Internal function to increment daily total active times for a node type.
     * @param nodeType The type of miner node.
     * @param activityTime The activity time to increment.
     * @return A boolean indicating whether the operation was successful.
     */
    function _incrementDailyTotalActiveTimes(
        MinerTypes.NodeType nodeType,
        uint256 activityTime
    ) internal returns (bool) {
        dailyNodesActivities[minerFormulas.getDate()][nodeType] += activityTime;
        return (true);
    }

    /**
     * @dev Internal function to increment daily active times for a miner node.
     * @param minerAddress The address of the miner node.
     * @param nodeType The type of miner node.
     * @param activityTime The activity time to increment.
     * @return A boolean indicating whether the operation was successful.
     */
    function _incrementDailyActiveTimes(
        address minerAddress,
        MinerTypes.NodeType nodeType,
        uint256 activityTime
    ) internal returns (bool) {
        dailyNodeActivity[minerFormulas.getDate()][minerAddress][
            nodeType
        ] += activityTime;
        return (true);
    }
}
