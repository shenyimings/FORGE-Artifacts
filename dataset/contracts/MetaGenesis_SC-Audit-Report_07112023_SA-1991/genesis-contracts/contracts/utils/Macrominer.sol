// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../libs/MinerTypes.sol";

import "../interfaces/IMinerHealthCheck.sol";
import "../interfaces/IMetaPoints.sol";
import "../interfaces/IMinerList.sol";

/**
 * @title Macrominer
 * @dev A contract for managing and voting on the status of macrominers.
 */
contract Macrominer is Initializable {
    /// @notice Struct to represent a vote
    struct Vote {
        uint256 voteId; // Identifier for the vote.
        uint256 point; // Accumulated voting points.
        bool exist; // Indicates if a vote exists.
    }

    /// @notice Constants for stake and vote point limits.
    uint256 public constant STAKE_AMOUNT = 100 ether;
    uint256 public constant VOTE_POINT_LIMIT = 100 ether;

    /// @notice Unique identifier for each vote.
    uint256 public voteId;

    /// @notice Addresses of external contracts
    IMinerHealthCheck public minerHealthCheck;
    IMetaPoints public metapoints;
    IMinerList public minerList;

    /// @notice Mapping to store votes for each miner and node type.
    mapping(address => mapping(MinerTypes.NodeType => Vote)) public votes;

    /// @notice voting begun
    event BeginVote(
        uint256 indexed voteId,
        address indexed miner,
        MinerTypes.NodeType indexed nodeType
    );
    /// @notice voted
    event Voted(
        uint256 indexed voteId,
        address indexed miner,
        MinerTypes.NodeType indexed nodeType,
        uint256 point
    );
    /// @notice voting ended
    event EndVote(
        uint256 indexed voteId,
        address indexed miner,
        MinerTypes.NodeType indexed nodeType
    );

    /**
     * Modifier to check if an address is a macrominer of a specific node type.
     */
    modifier isMiner(address miner, MinerTypes.NodeType nodeType) {
        require(
            minerList.isMiner(miner, nodeType),
            "Macrominer: Address is not macrominer"
        );
        _;
    }

    /**
     * Modifier to check if an address is not a macrominer of a specific node type.
     */
    modifier notMiner(address miner, MinerTypes.NodeType nodeType) {
        require(
            !minerList.isMiner(miner, nodeType),
            "Macrominer: Address is already macrominer"
        );
        _;
    }

    /**
     * Modifier to check if the node type is valid.
     */
    modifier isNodeTypeValid(MinerTypes.NodeType nodeType) {
        require(
            nodeType != MinerTypes.NodeType.Meta &&
                nodeType != MinerTypes.NodeType.Micro,
            "Macrominer: Wrong node type"
        );
        _;
    }

    /**
     * @dev The receive function is a special function that allows the contract to accept MTC transactions.
     */
    receive() external payable {}

    /**
     * @dev Initializes the contract with the specified addresses.
     * @param minerHealthCheckAddress Address of the MinerHealthCheck contract.
     * @param metapointsAddress Address of the MetaPoints contract.
     * @param minerListAddress Address of the MinerList contract.
     */
    function initialize(
        address minerHealthCheckAddress,
        address metapointsAddress,
        address minerListAddress
    ) external initializer {
        require(
            minerHealthCheckAddress != address(0) &&
                metapointsAddress != address(0) &&
                minerListAddress != address(0),
            "Macrominer: cannot set zero address"
        );
        minerHealthCheck = IMinerHealthCheck(minerHealthCheckAddress);
        metapoints = IMetaPoints(metapointsAddress);
        minerList = IMinerList(minerListAddress);
    }

    /**
     * @dev Set a miner as a macrominer of a specific node type.
     * @param nodeType The type of miner node to set as a macrominer.
     * @return true if the setting was successful.
     */
    function setMiner(
        MinerTypes.NodeType nodeType
    )
        external
        payable
        isNodeTypeValid(nodeType)
        notMiner(msg.sender, nodeType)
        returns (bool)
    {
        require(
            msg.value == STAKE_AMOUNT,
            "Macrominer: You have to stake as required STAKE_AMOUNT"
        );
        minerList.addMiner(msg.sender, nodeType);
        return (true);
    }

    /**
     * @dev Check the status of a miner and vote on it.
     * @param votedMinerAddress Address of the miner to check.
     * @param votedMinerNodeType Type of the miner node to check.
     * @param nodeType Type of the miner node making the vote.
     */
    function checkMinerStatus(
        address votedMinerAddress,
        MinerTypes.NodeType votedMinerNodeType,
        MinerTypes.NodeType nodeType
    )
        external
        isNodeTypeValid(votedMinerNodeType)
        isNodeTypeValid(nodeType)
        isMiner(votedMinerAddress, votedMinerNodeType)
        isMiner(msg.sender, nodeType)
    {
        // Check the health status of the voted miner.
        bool isAlive = minerHealthCheck.status(
            votedMinerAddress,
            votedMinerNodeType
        );

        Vote storage vote = votes[votedMinerAddress][votedMinerNodeType];

        if (isAlive == false) {
            uint256 mpBalance = metapoints.balanceOf(msg.sender);
            if (mpBalance + vote.point >= VOTE_POINT_LIMIT) {
                // If enough votes have been collected, kick the miner.
                _kickMiner(votedMinerAddress, votedMinerNodeType);

                emit EndVote(
                    vote.voteId,
                    votedMinerAddress,
                    votedMinerNodeType
                );
            } else {
                if (vote.point == 0) {
                    // Initialize the vote.
                    vote.voteId = voteId;
                    vote.point = mpBalance;
                    vote.exist = true;
                    voteId++;

                    emit BeginVote(
                        vote.voteId,
                        votedMinerAddress,
                        votedMinerNodeType
                    );
                } else {
                    // Add to an existing vote.
                    vote.point += mpBalance;

                    emit Voted(
                        vote.voteId,
                        votedMinerAddress,
                        votedMinerNodeType,
                        mpBalance
                    );
                }
            }
        } else if (vote.exist == true) {
            // Remove the vote if the miner is healthy.
            delete votes[votedMinerAddress][votedMinerNodeType];

            emit EndVote(vote.voteId, votedMinerAddress, votedMinerNodeType);
        }
    }

    /**
     * @dev Internal function to kick a miner and return their stake.
     * @param minerAddress Address of the miner to be kicked.
     * @param nodeType Type of the miner node.
     * @return true if the miner was successfully kicked.
     */
    function _kickMiner(
        address minerAddress,
        MinerTypes.NodeType nodeType
    ) internal returns (bool) {
        delete votes[minerAddress][nodeType];
        minerList.deleteMiner(minerAddress, nodeType);

        (bool sent, ) = payable(minerAddress).call{value: STAKE_AMOUNT}("");
        require(sent, "Macrominer: Unstake failed");

        return (true);
    }
}
