// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../helpers/RolesHandler.sol";
import "../interfaces/IRewardsPool.sol";
import "../libs/MinerTypes.sol";

/**
 * @title BlockValidator
 * @dev A smart contract for validating and finalizing blocks.
 */
contract BlockValidator is Initializable, RolesHandler {
    /// @notice a struct contains block credentials
    struct BlockPayload {
        address coinbase; // miner address of block
        bytes32 blockHash; // block hash of block
        uint256 blockReward; // incentive for block miner
        bool isFinalized; // finalization status of block
    }

    /// @notice holds last finalized block numbers
    uint256[32] public lastFinalizedBlockNumbers;
    /// @notice holds delay limit for block finalization
    uint8 public constant DELAY_LIMIT = 32;
    /// @notice RewardsPool instance address
    IRewardsPool public rewardsPool;
    /// @notice last finalized block id
    uint8 private _finalizedBlockId = 0;

    /// @notice a mapping that holds block payloads
    mapping(uint256 => BlockPayload) public blockPayloads;

    /// @notice payload is set
    event SetPayload(uint256 blockNumber);
    /// @notice block is finalized
    event FinalizeBlock(uint256 blockNumber);
    /// @notice metaminer block reward has claimed
    event Claim(
        address indexed coinbase,
        bytes32 indexed blockNumber,
        uint256 claimedAmount,
        uint256 blockReward
    );

    /**
     * @dev Initializes the BlockValidator contract with the addresses of the RewardsPool contract.
     * @param rewardsPoolAddress The address of the RewardsPool contract.
     */
    function initialize(address rewardsPoolAddress) external initializer {
        require(
            rewardsPoolAddress != address(0),
            "BlockValidator: cannot set zero address"
        );
        rewardsPool = IRewardsPool(rewardsPoolAddress);
    }

    /**
     * @dev Adds a payload to the queue for a specific block.
     * @param blockNumber The block number for which to set the payload.
     * @param blockPayload The block payload to set.
     * @return A boolean indicating whether the operation was successful.
     */
    function setBlockPayload(
        uint256 blockNumber,
        BlockPayload memory blockPayload
    ) external onlyValidatorRole(msg.sender) returns (bool) {
        require(
            blockPayloads[blockNumber].coinbase == address(0),
            "BlockValidator: Unable to set block payload"
        );
        require(
            blockhash(blockNumber) == blockPayload.blockHash,
            "BlockValidator: Mismatched block hash"
        );
        require(
            blockPayload.isFinalized == false,
            "BlockValidator: Block finalized before"
        );
        blockPayloads[blockNumber] = blockPayload;
        emit SetPayload(blockNumber);

        return true;
    }

    /**
     * @dev Finalizes a block by marking it as finalized.
     * @param blockNumber The block number to finalize.
     */
    function finalizeBlock(
        uint256 blockNumber
    ) external onlyManagerRole(msg.sender) {
        BlockPayload storage payload = blockPayloads[blockNumber];
        require(
            payload.coinbase != address(0),
            "BlockValidator: Unable to finalize block"
        );

        payload.isFinalized = true;

        if (_finalizedBlockId == DELAY_LIMIT) {
            uint8 i = 0;
            for (i; i < DELAY_LIMIT; i++) {
                BlockPayload memory bp = blockPayloads[
                    lastFinalizedBlockNumbers[i]
                ];

                uint256 result = rewardsPool.claim(bp.coinbase);
                emit Claim(bp.coinbase, bp.blockHash, result, bp.blockReward);
            }

            _finalizedBlockId = 0;
            delete lastFinalizedBlockNumbers;
        }

        lastFinalizedBlockNumbers[_finalizedBlockId] = blockNumber;
        _finalizedBlockId++;

        emit FinalizeBlock(blockNumber);
    }
}
