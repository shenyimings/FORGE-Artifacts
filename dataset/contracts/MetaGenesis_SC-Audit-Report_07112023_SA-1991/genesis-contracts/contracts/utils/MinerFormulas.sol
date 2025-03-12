// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../libs/MinerTypes.sol";
import "../interfaces/IMetaPoints.sol";
import "../interfaces/IMinerHealthCheck.sol";
import "../interfaces/IMinerList.sol";

/**
 * @title Miner Formulas
 * @dev A smart contract for managing reward calculation formulas for miners.
 */
contract MinerFormulas is Initializable {
    /// @notice Address of the MetaPoints contract
    IMetaPoints public metaPoints;
    /// @notice Address of the MinerList contract
    IMinerList public minerList;
    /// @notice Address of the MinerHealthCheck contract
    IMinerHealthCheck public minerHealthCheck;

    /// @notice Divider for percentage calculatations %100 => %10_000
    uint256 public constant BASE_DIVIDER = 10_000;
    /// @notice MinerPool contract's shareholder percent
    uint256 public constant METAMINER_MINER_POOL_SHARE_PERCENT = 5_000;
    /// @notice daily block count
    uint256 public constant METAMINER_DAILY_BLOCK_COUNT = 17_280;
    /// @notice prize pool for daily basis
    uint256 public constant METAMINER_DAILY_PRIZE_POOL = 166_666 * 10 ** 18;
    /// @notice metaminer maximum daily prize
    uint256 public constant METAMINER_DAILY_PRIZE_LIMIT = 450 * 10 ** 18;

    /// @notice macrominer(archive) maximum daily prize
    uint256 public constant MACROMINER_ARCHIVE_DAILY_MAX_REWARD =
        150 * 10 ** 18;
    /// @notice macrominer(fullnode) maximum daily prize
    uint256 public constant MACROMINER_FULLNODE_DAILY_MAX_REWARD =
        100 * 10 ** 18;
    /// @notice macrominer(light) maximum daily prize
    uint256 public constant MACROMINER_LIGHT_DAILY_MAX_REWARD = 50 * 10 ** 18;

    /// @notice hardcap of macrominer(archive) according to first formula
    uint256 public constant MACROMINER_ARCHIVE_HARD_CAP_OF_FIRST_FORMULA =
        135_000 * 10 ** 18;
    /// @notice hardcap of macrominer(archive) according to second formula
    uint256 public constant MACROMINER_ARCHIVE_HARD_CAP_OF_SECOND_FORMULA =
        15_000 * 10 ** 18;

    /// @notice hardcap of macrominer(fullnode) according to first formula
    uint256 public constant MACROMINER_FULLNODE_HARD_CAP_OF_FIRST_FORMULA =
        90_000 * 10 ** 18;
    /// @notice hardcap of macrominer(fullnode) according to second formula
    uint256 public constant MACROMINER_FULLNODE_HARD_CAP_OF_SECOND_FORMULA =
        10_000 * 10 ** 18;

    /// @notice hardcap of macrominer(light) according to first formula
    uint256 public constant MACROMINER_LIGHT_HARD_CAP_OF_FIRST_FORMULA =
        45_000 * 10 ** 18;
    /// @notice hardcap of macrominer(light) according to second formula
    uint256 public constant MACROMINER_LIGHT_HARD_CAP_OF_SECOND_FORMULA =
        5_000 * 10 ** 18;

    /// @notice total seconds in a day
    uint256 public constant SECONDS_IN_A_DAY = 86_400;

    /**
     * @dev Initializes the MinerFormulas contract with the provided addresses of dependencies.
     * @param metaPointsAddress The address of the MetaPoints contract.
     * @param minerListAddress The address of the MinerList contract.
     * @param minerHealthCheckAddress The address of the MinerHealthCheck contract.
     */
    function initialize(
        address metaPointsAddress,
        address minerListAddress,
        address minerHealthCheckAddress
    ) external initializer {
        require(
            metaPointsAddress != address(0) &&
                minerListAddress != address(0) &&
                minerHealthCheckAddress != address(0),
            "MinerFormulas: cannot set zero address"
        );
        metaPoints = IMetaPoints(metaPointsAddress);
        minerList = IMinerList(minerListAddress);
        minerHealthCheck = IMinerHealthCheck(minerHealthCheckAddress);
    }

    /**
     * @dev Calculate the Metaminer reward.
     * @return The calculated reward amount.
     */
    function calculateMetaminerReward() external view returns (uint256) {
        uint256 calculatedAmount = (METAMINER_DAILY_PRIZE_POOL /
            minerList.count(MinerTypes.NodeType.Meta));
        return
            calculatedAmount > METAMINER_DAILY_PRIZE_LIMIT
                ? METAMINER_DAILY_PRIZE_LIMIT /
                    (METAMINER_DAILY_BLOCK_COUNT /
                        minerList.count(MinerTypes.NodeType.Meta))
                : calculatedAmount /
                    (METAMINER_DAILY_BLOCK_COUNT /
                        minerList.count(MinerTypes.NodeType.Meta));
    }

    /**
     * @dev Calculate the MetaPoints reward.
     * @return The calculated reward amount.
     */
    function calculateMetaPointsReward() external pure returns (uint256) {
        return (1 ether / SECONDS_IN_A_DAY);
    }

    /**
     * @dev Calculate the daily pool rewards from the first formula for macro miners.
     * @param nodeType The type of macro miner.
     * @return The calculated reward amount.
     */
    function calculateDailyPoolRewardsFromFirstFormula(
        MinerTypes.NodeType nodeType
    ) external view returns (uint256) {
        uint256 TOTAL_NODE_COUNT = 0;
        uint256 DAILY_CALC_POOL_REWARD = 0;

        if (nodeType == MinerTypes.NodeType.MacroArchive) {
            TOTAL_NODE_COUNT = minerList.count(
                MinerTypes.NodeType.MacroArchive
            );
            DAILY_CALC_POOL_REWARD = MACROMINER_ARCHIVE_HARD_CAP_OF_FIRST_FORMULA;
        } else if (nodeType == MinerTypes.NodeType.MacroFullnode) {
            TOTAL_NODE_COUNT = minerList.count(
                MinerTypes.NodeType.MacroFullnode
            );
            DAILY_CALC_POOL_REWARD = MACROMINER_FULLNODE_HARD_CAP_OF_FIRST_FORMULA;
        } else if (nodeType == MinerTypes.NodeType.MacroLight) {
            TOTAL_NODE_COUNT = minerList.count(MinerTypes.NodeType.MacroLight);
            DAILY_CALC_POOL_REWARD = MACROMINER_LIGHT_HARD_CAP_OF_FIRST_FORMULA;
        } else {
            return (0);
        }

        uint256 formula = ((DAILY_CALC_POOL_REWARD / (24 * TOTAL_NODE_COUNT)) /
            SECONDS_IN_A_DAY);
        return (formula);
    }

    /**
     * @dev Calculate the daily pool rewards from the second formula for macro miners.
     * @param minerAddress The address of the miner.
     * @param nodeType The type of macro miner.
     * @return The calculated reward amount.
     */
    function calculateDailyPoolRewardsFromSecondFormula(
        address minerAddress,
        MinerTypes.NodeType nodeType
    ) external view returns (uint256) {
        uint256 TOTAL_NODE_COUNT = 0;
        uint256 REST_POOL_AMOUNT = 0;
        uint256 MINER_META_POINT = _balaceOfMP(minerAddress);
        uint256 TOTAL_SUPPLY_META_POINTS = _totalSupplyMP();

        uint256 MINERS_TOTAL_ACTIVITIES = minerHealthCheck.dailyNodesActivities(
            _getDate(),
            nodeType
        );

        uint256 MINER_ACTIVITY = minerHealthCheck.dailyNodeActivity(
            _getDate(),
            minerAddress,
            nodeType
        );

        if (nodeType == MinerTypes.NodeType.MacroArchive) {
            TOTAL_NODE_COUNT = minerList.count(
                MinerTypes.NodeType.MacroArchive
            );
            REST_POOL_AMOUNT = MACROMINER_ARCHIVE_HARD_CAP_OF_SECOND_FORMULA;
        } else if (nodeType == MinerTypes.NodeType.MacroFullnode) {
            TOTAL_NODE_COUNT = minerList.count(
                MinerTypes.NodeType.MacroFullnode
            );
            REST_POOL_AMOUNT = MACROMINER_FULLNODE_HARD_CAP_OF_SECOND_FORMULA;
        } else if (nodeType == MinerTypes.NodeType.MacroLight) {
            TOTAL_NODE_COUNT = minerList.count(MinerTypes.NodeType.MacroLight);
            REST_POOL_AMOUNT = MACROMINER_LIGHT_HARD_CAP_OF_SECOND_FORMULA;
        } else {
            return (0);
        }
        uint256 formula = ((((REST_POOL_AMOUNT * 1e24) /
            (TOTAL_SUPPLY_META_POINTS *
                ((MINERS_TOTAL_ACTIVITIES * 1e10) / (TOTAL_NODE_COUNT * 24)))) *
            MINER_META_POINT *
            (MINER_ACTIVITY / 24)) / (SECONDS_IN_A_DAY * 1e14));
        return (formula);
    }

    /**
     * @dev Get the current date in terms of the number of days since the Unix epoch.
     * @return The current date.
     */
    function getDate() external view returns (uint256) {
        return _getDate();
    }

    /**
     * @dev Internal function to calculate the current date in terms of
     * the number of days since the Unix epoch.
     * @return The current date.
     */
    function _getDate() internal view returns (uint256) {
        // calculate today date from block.timestamp and return
        return uint256(block.timestamp) / SECONDS_IN_A_DAY;
    }

    /**
     * @dev Internal function to get the Meta Points balance of a miner.
     * @param miner The address of the miner.
     * @return The Meta Points balance of the miner.
     */
    function _balaceOfMP(address miner) internal view returns (uint256) {
        return (metaPoints.balanceOf(miner));
    }

    /**
     * @dev Internal function to get the total supply of Meta Points.
     * @return The total supply of Meta Points.
     */
    function _totalSupplyMP() internal view returns (uint256) {
        return (metaPoints.totalSupply());
    }
}
