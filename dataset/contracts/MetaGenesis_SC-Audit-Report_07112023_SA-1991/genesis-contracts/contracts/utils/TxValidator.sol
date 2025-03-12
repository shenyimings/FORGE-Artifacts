// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../helpers/RolesHandler.sol";
import "../interfaces/IMinerList.sol";
import "../interfaces/IMinerPool.sol";
import "../interfaces/IMetaPoints.sol";
import "../interfaces/IMinerFormulas.sol";
import "../interfaces/IMinerHealthCheck.sol";
import "../libs/MinerTypes.sol";

/**
 * @title TxValidator
 * @dev Contract for validating transactions and managing votes on transactions.
 */
// A long time ago in a galaxy far, far away!
contract TxValidator is Initializable, RolesHandler {
    /// @notice Struct to represent a vote
    struct Vote {
        MinerTypes.NodeType nodeType; // Type of miner node associated with the voter
        address voter; // Address of the voter
        bool decision; // The decision of the voter (true or false)
    }
    /// @notice Struct to store transaction data
    struct TxPayload {
        address handler; // The handler of the transaction
        uint256 reward; // The reward associated with the transaction
        uint256 votePoint; // The total vote points received for the transaction
        bool voteResult; // The result of the transaction vote
        bool expired; // Whether the transaction has expired
        uint256 expireTime; // The timestamp when the transaction expires
        bool done; // Whether the transaction is completed
    }

    /// @notice Enum to represent the state of a transaction
    enum TransactionState {
        Pending, // Transaction is pending validation
        Completed, // Transaction has been completed successfully
        Expired // Transaction has expired and is no longer valid
    }

    /// @notice Parameters for transaction validation
    uint256 public constant VOTE_POINT_LIMIT = 100 ether;
    uint256 public constant VOTE_COUNT_LIMIT = 32;
    uint256 public constant VOTE_POINT = 2 ether;
    uint256 public constant EXPIRE_TIME = 5 minutes;
    uint256 public constant HANDLER_PERCENT = 5_000;

    /// @notice Addresses of dependency contracts
    IMinerList public minerList;
    IMinerPool public minerPool;
    IMetaPoints public metaPoints;
    IMinerFormulas public minerFormulas;
    IMinerHealthCheck public minerHealthCheck;

    /// @notice Mapping to store transaction data based on its hash
    mapping(bytes32 => TxPayload) public txPayloads;
    /// @notice Mapping to store votes for each transaction
    mapping(bytes32 => mapping(uint256 => Vote)) public txVotes;
    /// @notice Mapping to store the count of votes for each transaction
    mapping(bytes32 => uint256) public txVotesCount;
    /// @notice Mapping to keep track of whether an address has voted for a transaction
    mapping(bytes32 => mapping(address => bool)) public previousVotes;

    /// @notice new transaction added
    event AddTransaction(
        bytes32 indexed txHash,
        address indexed handler,
        uint256 reward
    );
    /// @notice voted for previously saved transaction
    event VoteTransaction(
        bytes32 indexed txHash,
        address indexed voter,
        bool decision
    );

    /// @notice transaction voting completely done
    event DoneTransaction(bytes32 indexed txHash, uint256 reward);
    /// @notice transaction is expired
    event ExpireTransaction(bytes32 indexed txHash);

    /**
     * @dev Initializes the contract with required addresses and parameters.
     * @param minerListAddress Address of the MinerList contract.
     * @param metaPointsAddress Address of the MetaPoints contract.
     * @param minerFormulasAddress Address of the MinerFormulas contract.
     * @param minerHealthCheckAddress Address of the MinerHealthCheck contract.
     * @param minerPoolAddress Address of the MinerPool contract.
     */
    function initialize(
        address minerListAddress,
        address metaPointsAddress,
        address minerFormulasAddress,
        address minerHealthCheckAddress,
        address minerPoolAddress
    ) external initializer {
        require(
            minerListAddress != address(0) &&
                metaPointsAddress != address(0) &&
                minerFormulasAddress != address(0) &&
                minerHealthCheckAddress != address(0) &&
                minerPoolAddress != address(0),
            "TxValidator: cannot set zero address"
        );

        minerList = IMinerList(minerListAddress);
        metaPoints = IMetaPoints(metaPointsAddress);
        minerFormulas = IMinerFormulas(minerFormulasAddress);
        minerHealthCheck = IMinerHealthCheck(minerHealthCheckAddress);
        minerPool = IMinerPool(minerPoolAddress);
    }

    /**
     * @dev Allows a manager to add a new transaction for validation.
     * @param txHash The hash of the transaction.
     * @param handler The handler of the transaction.
     * @param reward The reward associated with the transaction.
     * @param nodeType The type of miner node associated with the transaction.
     * @return A boolean indicating the success of the operation.
     */
    function addTransaction(
        bytes32 txHash,
        address handler,
        uint256 reward,
        MinerTypes.NodeType nodeType
    ) external onlyManagerRole(msg.sender) returns (bool) {
        bool isAlive = minerHealthCheck.status(handler, nodeType);
        require(isAlive, "TxValidator: Miner is not active");
        TxPayload storage txPayload = txPayloads[txHash];
        require(
            txPayload.handler == address(0),
            "TxValidator: Tx is already exist"
        );
        txPayloads[txHash] = TxPayload(
            handler,
            reward,
            0,
            false,
            false,
            (block.timestamp + EXPIRE_TIME),
            false
        );
        emit AddTransaction(txHash, handler, reward);
        return (true);
    }

    /**
     * @dev Allows a user to vote on a transaction.
     * @param txHash The hash of the transaction.
     * @param decision The decision of the voter (true or false).
     * @param nodeType The type of miner node associated with the voter.
     * @return A boolean indicating the success of the operation.
     */
    function voteTransaction(
        bytes32 txHash,
        bool decision,
        MinerTypes.NodeType nodeType
    ) external returns (bool) {
        bool isAlive = minerHealthCheck.status(msg.sender, nodeType);
        require(isAlive, "TxValidator: Activity is not as expected");
        TxPayload storage txPayload = txPayloads[txHash];
        address voter = msg.sender;
        TransactionState txState = _checkTransactionState(txHash);

        require(
            txPayload.handler != address(0),
            "TxValidator: Tx doesn't exist"
        );
        require(
            txState == TransactionState.Pending,
            "TxValidator: Tx is closed"
        );
        require(
            previousVotes[txHash][voter] != true,
            "TxValidator: Already voted"
        );
        require(
            voter != txPayload.handler,
            "TxValidator: Handler cannot vote for tx"
        );
        require(
            minerList.list(voter, nodeType) == true &&
                nodeType != MinerTypes.NodeType.Meta,
            "TxValidator: Address is not eligible to vote"
        );

        uint256 votePoint = _calculateVotePoint(voter, nodeType);
        uint256 txVoteCount = txVotesCount[txHash];

        txPayload.votePoint += votePoint;
        txVotes[txHash][txVoteCount] = Vote(nodeType, voter, decision);
        previousVotes[txHash][voter] = true;
        txVotesCount[txHash]++;

        emit VoteTransaction(txHash, voter, decision);
        _checkTransactionState(txHash);

        return (true);
    }

    /**
     * @dev Checks the current state of a transaction and handles the state transitions.
     * @param txHash The hash of the transaction.
     * @return The state of the transaction (Pending, Completed, or Expired).
     */
    function checkTransactionState(
        bytes32 txHash
    ) external returns (TransactionState) {
        return (_checkTransactionState(txHash));
    }

    /**
     * @dev Internal function to check the state of a transaction and handle state transitions.
     * @param txHash The hash of the transaction.
     * @return The state of the transaction (Pending, Completed, or Expired).
     */
    function _checkTransactionState(
        bytes32 txHash
    ) internal returns (TransactionState) {
        TxPayload storage txPayload = txPayloads[txHash];
        uint256 txVoteCount = txVotesCount[txHash];

        TransactionState state = TransactionState.Pending;

        if (
            (txPayload.votePoint >= VOTE_POINT_LIMIT ||
                txVoteCount == VOTE_COUNT_LIMIT) && txPayload.done == false
        ) {
            txPayload.done = true;
            _shareRewards(txHash);
            emit DoneTransaction(txHash, txPayload.reward);
        }
        if (txPayload.done != true && txPayload.expireTime < block.timestamp) {
            txPayload.expired = true;
            emit ExpireTransaction(txHash);
        }

        if (txPayload.done == true) {
            state = TransactionState.Completed;
        }
        if (txPayload.expired == true) {
            state = TransactionState.Expired;
        }

        return state;
    }

    /**
     * @dev Internal function to calculate the vote point for a voter.
     * @param voter The address of the voter.
     * @param nodeType The type of miner node associated with the voter.
     * @return The calculated vote point.
     */
    function _calculateVotePoint(
        address voter,
        MinerTypes.NodeType nodeType
    ) internal view returns (uint256) {
        uint256 votePoint = VOTE_POINT;
        if (nodeType == MinerTypes.NodeType.Micro) {
            return votePoint;
        }

        uint256 metaPointsBalance = metaPoints.balanceOf(voter);
        votePoint *= (metaPointsBalance > 0 ? metaPointsBalance / 1 ether : 1);

        return votePoint;
    }

    /**
     * @dev Internal function to distribute rewards for a completed transaction.
     * @param txHash The hash of the completed transaction.
     * @return A boolean indicating the success of the operation.
     */
    function _shareRewards(bytes32 txHash) internal returns (bool) {
        TxPayload storage txPayload = txPayloads[txHash];
        uint256 txVoteCount = txVotesCount[txHash];

        address[32] memory trueVoters;
        address[32] memory falseVoters;
        uint256 trueVotersLength = 0;
        uint256 falseVotersLength = 0;

        for (uint256 i = 0; i < txVoteCount; i++) {
            Vote memory vote = txVotes[txHash][i];
            if (vote.decision) {
                trueVoters[trueVotersLength] = vote.voter;
                trueVotersLength++;
                continue;
            }
            falseVoters[falseVotersLength] = vote.voter;
            falseVotersLength++;
        }

        bool tie = (trueVotersLength == falseVotersLength ? true : false);
        bool decision = (trueVotersLength > falseVotersLength ? true : false);

        if (!tie) {
            uint256 txReward = txPayload.reward;
            uint256 minerPoolPercent = (minerFormulas.BASE_DIVIDER() /
                minerFormulas.METAMINER_MINER_POOL_SHARE_PERCENT());
            txReward /= minerPoolPercent;

            uint256 handlerReward = txReward /
                (minerFormulas.BASE_DIVIDER() / HANDLER_PERCENT);
            if (decision) {
                uint256 voteReward = (txReward - handlerReward) /
                    trueVotersLength;
                minerPool.claimTxReward(txPayload.handler, handlerReward);
                for (uint256 i = 0; i < trueVotersLength; i++) {
                    address trueVoter = trueVoters[i];
                    minerPool.claimTxReward(trueVoter, voteReward);
                }
            } else {
                uint256 voteReward = txReward / falseVotersLength;
                for (uint256 i = 0; i < falseVotersLength; i++) {
                    address falseVoter = falseVoters[i];
                    minerPool.claimTxReward(falseVoter, voteReward);
                }
            }
        }
        return (true);
    }
}
