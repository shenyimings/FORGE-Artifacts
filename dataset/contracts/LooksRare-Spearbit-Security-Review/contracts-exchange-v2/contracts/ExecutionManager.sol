// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "./libraries/OrderStructs.sol";

// Interfaces
import {IExecutionManager} from "./interfaces/IExecutionManager.sol";
import {ICreatorFeeManager} from "./interfaces/ICreatorFeeManager.sol";

// Direct dependencies
import {InheritedStrategy} from "./InheritedStrategy.sol";
import {NonceManager} from "./NonceManager.sol";
import {StrategyManager} from "./StrategyManager.sol";

/**
 * @title ExecutionManager
 * @notice This contract handles the execution and resolution of transactions. A transaction is executed on-chain
 *         when an off-chain maker order is matched by on-chain taker order of a different kind.
 *         For instance, a taker ask is executed against a maker bid (or a taker bid against a maker ask).
 * @author LooksRare protocol team (ðŸ‘€,ðŸ’Ž)
 */
contract ExecutionManager is InheritedStrategy, NonceManager, StrategyManager, IExecutionManager {
    /**
     * @notice Protocol fee recipient.
     */
    address public protocolFeeRecipient;

    /**
     * @notice Maximum creator fee (in basis point).
     */
    uint16 public maxCreatorFeeBp = 1_000;

    /**
     * @notice Creator fee manager.
     */
    ICreatorFeeManager public creatorFeeManager;

    /**
     * @notice Constructor
     * @param _owner Owner address
     */
    constructor(address _owner) StrategyManager(_owner) {}

    /**
     * @notice This function allows the owner to update the creator fee manager address.
     * @param newCreatorFeeManager Address of the creator fee manager
     * @dev Only callable by owner.
     */
    function updateCreatorFeeManager(address newCreatorFeeManager) external onlyOwner {
        creatorFeeManager = ICreatorFeeManager(newCreatorFeeManager);
        emit NewCreatorFeeManager(newCreatorFeeManager);
    }

    /**
     * @notice This function allows the owner to update the maximum creator fee (in basis point).
     * @param newMaxCreatorFeeBp New maximum creator fee (in basis point)
     * @dev The maximum value that can be set is 25%.
     *       Only callable by owner.
     */
    function updateMaxCreatorFeeBp(uint16 newMaxCreatorFeeBp) external onlyOwner {
        if (newMaxCreatorFeeBp > 2_500) {
            revert CreatorFeeBpTooHigh();
        }

        maxCreatorFeeBp = newMaxCreatorFeeBp;

        emit NewMaxCreatorFeeBp(newMaxCreatorFeeBp);
    }

    /**
     * @notice This function allows the owner to update the protocol fee recipient.
     * @param newProtocolFeeRecipient New protocol fee recipient address
     * @dev Only callable by owner.
     */
    function updateProtocolFeeRecipient(address newProtocolFeeRecipient) external onlyOwner {
        if (newProtocolFeeRecipient == address(0)) {
            revert NewProtocolFeeRecipientCannotBeNullAddress();
        }

        protocolFeeRecipient = newProtocolFeeRecipient;
        emit NewProtocolFeeRecipient(newProtocolFeeRecipient);
    }

    /**
     * @notice This function is internal and used to execute a transaction initiated by a taker ask.
     * @param takerAsk Taker ask struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid Maker bid struct (contains bid-specific parameter for the maker side of the transaction)
     * @return itemIds Array of item ids to be traded
     * @return amounts Array of amounts for each item id
     * @return recipients Array of recipient addresses
     * @return fees Array of fee amounts for recipients
     * @return isNonceInvalidated Whether the order's nonce will be invalidated after executing the order
     */
    function _executeStrategyForTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid,
        address sender
    )
        internal
        returns (
            uint256[] memory itemIds,
            uint256[] memory amounts,
            address[3] memory recipients,
            uint256[3] memory fees,
            bool isNonceInvalidated
        )
    {
        uint256 price;

        // Verify the order validity for timestamps
        _verifyOrderTimestampValidity(makerBid.startTime, makerBid.endTime);

        if (makerBid.strategyId == 0) {
            _verifyStandardSaleStrategyWithTakerAsk(takerAsk, makerBid);
            (price, itemIds, amounts) = (makerBid.maxPrice, makerBid.itemIds, makerBid.amounts);
            isNonceInvalidated = true;
        } else {
            if (strategyInfo[makerBid.strategyId].isActive) {
                if (!strategyInfo[makerBid.strategyId].isMakerBid) {
                    revert NoSelectorForMakerBid();
                }

                (bool status, bytes memory data) = strategyInfo[makerBid.strategyId].implementation.call(
                    abi.encodeWithSelector(strategyInfo[makerBid.strategyId].selector, takerAsk, makerBid)
                );

                if (!status) {
                    // @dev It forwards the revertion message from the low-level call
                    assembly {
                        revert(add(data, 32), mload(data))
                    }
                }

                (price, itemIds, amounts, isNonceInvalidated) = abi.decode(data, (uint256, uint256[], uint256[], bool));
            } else {
                revert StrategyNotAvailable(makerBid.strategyId);
            }
        }

        // Creator fee and adjustment of protocol fee
        if (address(creatorFeeManager) != address(0)) {
            (recipients[1], fees[1]) = creatorFeeManager.viewCreatorFeeInfo(makerBid.collection, price, itemIds);

            if (recipients[1] == address(0)) {
                // If recipient is null address, creator fee is set at 0
                fees[1] = 0;
            } else if (fees[1] * 10_000 > (price * uint256(maxCreatorFeeBp))) {
                // If creator fee is higher than tolerated, it reverts
                revert CreatorFeeBpTooHigh();
            }
        }

        // Compute minimum total fee amount
        uint256 minTotalFeeAmount = (price * strategyInfo[makerBid.strategyId].minTotalFeeBp) / 10_000;

        if (fees[1] == 0) {
            // If creator fee is null, protocol fee is set as the minimum total fee amount
            fees[0] = minTotalFeeAmount;
            // Net fee for seller
            fees[2] = price - fees[0];
        } else {
            // If there is a creator fee information, the protocol fee amount can be calculated
            fees[0] = _calculateProtocolFeeAmount(price, makerBid.strategyId, fees[1], minTotalFeeAmount);
            // Net fee for seller
            fees[2] = price - fees[1] - fees[0];
        }

        recipients[0] = protocolFeeRecipient;
        recipients[2] = takerAsk.recipient == address(0) ? sender : takerAsk.recipient;
    }

    /**
     * @notice This function is internal and used to execute a transaction initiated by a taker bid.
     * @param takerBid Taker bid struct (contains the taker bid-specific parameters for the execution of the transaction)
     * @param makerAsk Maker ask struct (contains ask-specific parameter for the maker side of the transaction)
     * @return itemIds Array of item ids to be traded
     * @return amounts Array of amounts for each item id
     * @return recipients Array of recipient addresses
     * @return fees Array of fee amounts for recipients
     * @return isNonceInvalidated Whether the order's nonce will be invalidated after executing the order
     */
    function _executeStrategyForTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk
    )
        internal
        returns (
            uint256[] memory itemIds,
            uint256[] memory amounts,
            address[3] memory recipients,
            uint256[3] memory fees,
            bool isNonceInvalidated
        )
    {
        uint256 price;

        _verifyOrderTimestampValidity(makerAsk.startTime, makerAsk.endTime);

        if (makerAsk.strategyId == 0) {
            _verifyStandardSaleStrategyWithTakerBid(takerBid, makerAsk);
            (price, itemIds, amounts) = (makerAsk.minPrice, makerAsk.itemIds, makerAsk.amounts);
            isNonceInvalidated = true;
        } else {
            if (strategyInfo[makerAsk.strategyId].isActive) {
                if (strategyInfo[makerAsk.strategyId].isMakerBid) {
                    revert NoSelectorForMakerAsk();
                }

                (bool status, bytes memory data) = strategyInfo[makerAsk.strategyId].implementation.call(
                    abi.encodeWithSelector(strategyInfo[makerAsk.strategyId].selector, takerBid, makerAsk)
                );

                if (!status) {
                    // @dev It forwards the revertion message from the low-level call
                    assembly {
                        revert(add(data, 32), mload(data))
                    }
                }

                (price, itemIds, amounts, isNonceInvalidated) = abi.decode(data, (uint256, uint256[], uint256[], bool));
            } else {
                revert StrategyNotAvailable(makerAsk.strategyId);
            }
        }

        // Creator fee amount and adjustment of protocol fee amount
        if (address(creatorFeeManager) != address(0)) {
            (recipients[1], fees[1]) = creatorFeeManager.viewCreatorFeeInfo(makerAsk.collection, price, itemIds);

            if (recipients[1] == address(0)) {
                // If recipient is null address, creator fee is set at 0
                fees[1] = 0;
            } else if (fees[1] * 10_000 > (price * uint256(maxCreatorFeeBp))) {
                // If creator fee is higher than tolerated, it reverts
                revert CreatorFeeBpTooHigh();
            }
        }

        // Compute minimum total fee amount
        uint256 minTotalFeeAmount = (price * strategyInfo[makerAsk.strategyId].minTotalFeeBp) / 10_000;

        if (fees[1] == 0) {
            // If creator fee is null, protocol fee is set as the minimum total fee amount
            fees[0] = minTotalFeeAmount;
            // Net fee amount for seller
            fees[2] = price - fees[0];
        } else {
            // If there is a creator fee information, the protocol fee amount can be calculated
            fees[0] = _calculateProtocolFeeAmount(price, makerAsk.strategyId, fees[1], minTotalFeeAmount);
            // Net fee amount for seller
            fees[2] = price - fees[1] - fees[0];
        }

        recipients[0] = protocolFeeRecipient;
        recipients[2] = makerAsk.signer;
    }

    /**
     * @notice This function is internal and used to calculate the protocol fee amount for a given set of fees.
     * @param price Transaction price
     * @param strategyId Strategy id
     * @param creatorFeeAmount Creator fee amount
     * @param minTotalFeeAmount Min total fee amount
     * @return protocolFeeAmount Protocol fee amount
     */
    function _calculateProtocolFeeAmount(
        uint256 price,
        uint256 strategyId,
        uint256 creatorFeeAmount,
        uint256 minTotalFeeAmount
    ) private view returns (uint256 protocolFeeAmount) {
        protocolFeeAmount = (price * strategyInfo[strategyId].standardProtocolFeeBp) / 10_000;

        if (protocolFeeAmount + creatorFeeAmount < minTotalFeeAmount) {
            protocolFeeAmount = minTotalFeeAmount - creatorFeeAmount;
        }
    }

    /**
     * @notice This function is internal and used to verify the validity of an order in the context of the current block timestamps.
     * @param startTime Start timestamp
     * @param endTime End timestamp
     */
    function _verifyOrderTimestampValidity(uint256 startTime, uint256 endTime) private view {
        // if (startTime > block.timestamp || endTime < block.timestamp) revert OutsideOfTimeRange();
        assembly {
            if or(gt(startTime, timestamp()), lt(endTime, timestamp())) {
                mstore(0x00, 0x7476320f)
                revert(0x1c, 0x04)
            }
        }
    }
}
