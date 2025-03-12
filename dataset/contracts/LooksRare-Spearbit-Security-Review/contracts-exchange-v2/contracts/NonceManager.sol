// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Interfaces and errors
import {INonceManager} from "./interfaces/INonceManager.sol";
import {WrongLengths} from "./interfaces/SharedErrors.sol";

/**
 * @title NonceManager
 * @notice This contract handles the nonce logic that is used for invalidating maker orders that exist off-chain.
 *         The nonce logic revolves around three parts at the user level:
 *         - order nonce (orders sharing an order nonce are conditional, OCO-like)
 *         - subset (orders can be grouped under a same subset)
 *         - bid/ask (all orders can be executed only if the bid/ask nonce matches the user's one on-chain)
 *         Only the order nonce is invalidated at the time of the execution of a maker order that contains it.
 * @author LooksRare protocol team (ðŸ‘€,ðŸ’Ž)
 */
contract NonceManager is INonceManager {
    /**
     * @notice Magic value nonce returned if executed (or cancelled).
     */
    bytes32 public constant MAGIC_VALUE_ORDER_NONCE_EXECUTED = keccak256("ORDER_NONCE_EXECUTED");

    /**
     * @notice This tracks the bid and ask nonces for a user address.
     */
    mapping(address => UserBidAskNonces) public userBidAskNonces;

    /**
     * @notice This checks whether the order nonce for a user was executed or cancelled.
     */
    mapping(address => mapping(uint256 => bytes32)) public userOrderNonce;

    /**
     * @notice This checks whether the subset nonce for a user was cancelled.
     */
    mapping(address => mapping(uint256 => bool)) public userSubsetNonce;

    /**
     * @notice This function allows a user to cancel an array of order nonces.
     * @param orderNonces Array of order nonces
     */
    function cancelOrderNonces(uint256[] calldata orderNonces) external {
        uint256 length = orderNonces.length;
        if (length == 0) {
            revert WrongLengths();
        }

        for (uint256 i; i < length; ) {
            userOrderNonce[msg.sender][orderNonces[i]] = MAGIC_VALUE_ORDER_NONCE_EXECUTED;
            unchecked {
                ++i;
            }
        }

        emit OrderNoncesCancelled(msg.sender, orderNonces);
    }

    /**
     * @notice This function allows a user to cancel an array of subset nonces.
     * @param subsetNonces Array of subset nonces
     */
    function cancelSubsetNonces(uint256[] calldata subsetNonces) external {
        uint256 length = subsetNonces.length;

        if (length == 0) {
            revert WrongLengths();
        }

        for (uint256 i; i < length; ) {
            userSubsetNonce[msg.sender][subsetNonces[i]] = true;
            unchecked {
                ++i;
            }
        }

        emit SubsetNoncesCancelled(msg.sender, subsetNonces);
    }

    /**
     * @notice This function allows a user to increment her bid/ask nonces.
     * @param bid Whether to increment the user bid nonce
     * @param ask Whether to increment the user ask nonce
     */
    function incrementBidAskNonces(bool bid, bool ask) external {
        uint256 _bidNonce = userBidAskNonces[msg.sender].bidNonce;
        uint256 _askNonce = userBidAskNonces[msg.sender].askNonce;
        if (bid) {
            userBidAskNonces[msg.sender].bidNonce = ++_bidNonce;
        }
        if (ask) {
            userBidAskNonces[msg.sender].askNonce = ++_askNonce;
        }

        emit NewBidAskNonces(msg.sender, _bidNonce, _askNonce);
    }
}
