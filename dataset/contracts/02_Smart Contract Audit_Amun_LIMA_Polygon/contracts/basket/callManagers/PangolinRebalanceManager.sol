// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.5;

import {
    IPangolinRouter
} from "@pangolindex/exchange-contracts/contracts/pangolin-periphery/interfaces/IPangolinRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IExperiPie.sol";
import "../interfaces/IPangolinRebalanceManager.sol";

contract PangolinRebalanceManager is IPangolinRebalanceManager {
    IExperiPie public immutable basket;
    IPangolinRouter public immutable pangolin;
    address public rebalanceManager;
    IERC20 private immutable nativeToken;

    event Rebalanced(address indexed basket);
    event Swaped(
        address indexed basket,
        address indexed fromToken,
        address indexed toToken,
        uint256 quantity,
        uint256 returnedQuantity
    );
    event RebalanceManagerSet(address indexed rebalanceManager);

    constructor(
        address _basket,
        address _pangolin,
        address _nativeToken
    ) {
        require(_basket != address(0), "INVALID_BASKET");
        require(_pangolin != address(0), "INVALID_PANGOLIN");
        require(_nativeToken != address(0), "INVALID_NATIVE_TOKEN");

        basket = IExperiPie(_basket);
        pangolin = IPangolinRouter(_pangolin);
        rebalanceManager = msg.sender;
        nativeToken = IERC20(_nativeToken);
    }

    modifier onlyRebalanceManager() {
        require(msg.sender == rebalanceManager, "NOT_ALLOWED");
        _;
    }

    function setRebalanceManager(address _rebalanceManager)
        external
        onlyRebalanceManager
    {
        rebalanceManager = _rebalanceManager;
        emit RebalanceManagerSet(_rebalanceManager);
    }

    function _swap(
        address fromToken,
        address toToken,
        uint256 quantity,
        uint256 minReturn,
        address recipient,
        uint256 deadline
    ) internal {
        // approve fromToken to pangolin
        // IERC20(fromToken).approve(address(pangolin), uint256(-1));
        if (
            IERC20(fromToken).allowance(address(basket), address(pangolin)) <
            quantity
        ) {
            basket.singleCall(
                fromToken,
                abi.encodeWithSelector(
                    IERC20(fromToken).approve.selector,
                    address(pangolin),
                    uint256(-1)
                ),
                0
            );
        }

        // Swap on pangolin
        // pangolin.swapExactTokensForTokens(amount, minReturnAmount, path, recipient, deadline);
        address[] memory path = new address[](3);
        path[0] = fromToken;
        path[1] = address(nativeToken);
        path[2] = toToken;
        basket.singleCall(
            address(pangolin),
            abi.encodeWithSelector(
                pangolin.swapExactTokensForTokens.selector,
                quantity,
                minReturn,
                path,
                recipient,
                deadline
            ),
            0
        );

        emit Swaped(address(basket), fromToken, toToken, quantity, minReturn);
    }

    function removeToken(address _token) internal {
        uint256 balance = basket.balance(_token);
        bool inPool = basket.getTokenInPool(_token);
        //if there is a token balance of the token is not in the pool, skip
        if (balance != 0 || !inPool) {
            return;
        }

        // remove token
        basket.singleCall(
            address(basket),
            abi.encodeWithSelector(basket.removeToken.selector, _token),
            0
        );
    }

    function addToken(address _token) internal {
        uint256 balance = basket.balance(_token);
        bool inPool = basket.getTokenInPool(_token);
        // If token has no balance or is already in the pool, skip
        if (balance == 0 || inPool) {
            return;
        }

        // add token
        basket.singleCall(
            address(basket),
            abi.encodeWithSelector(basket.addToken.selector, _token),
            0
        );
    }

    function lockBasketData(uint256 _block)
        internal
        returns (bytes memory data)
    {
        basket.singleCall(
            address(basket),
            abi.encodeWithSelector(basket.setLock.selector, _block),
            0
        );
    }

    /**
        @notice Rebalance underling token
        @param _swaps Swaps to perform
        @param _deadline Unix timestamp after which the transaction will revert.
    */
    function rebalance(SwapStruct[] calldata _swaps, uint256 _deadline)
        external
        override
        onlyRebalanceManager
    {
        lockBasketData(block.number + 30);

        // remove token from array
        for (uint256 i; i < _swaps.length; i++) {
            SwapStruct memory swap = _swaps[i];

            //swap token
            _swap(
                swap.from,
                swap.to,
                swap.quantity,
                swap.minReturn,
                address(basket),
                _deadline
            );

            //add to token if missing
            addToken(swap.to);

            //remove from token if resulting quantity is 0
            removeToken(swap.from);
        }
        emit Rebalanced(address(basket));
    }
}
