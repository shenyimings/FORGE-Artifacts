// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.9;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import '../interfaces/IPool.sol';
import '../interfaces/IPlatypusRouter01.sol';

/**
 * @title PlatypusRouter01
 * @notice Allows routing on different platypus pools
 * @dev Owner is allowed and required to approve token spending by pools via approveSpendingByPool function
 */
contract PlatypusRouter01 is Ownable, ReentrancyGuard, IPlatypusRouter01 {
    using SafeERC20 for IERC20;

    /// @dev Modifier ensuring a certain deadline for a function to complete execution
    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, 'expired');
        _;
    }

    /// @notice approve spending of router tokens by pool
    /// @param tokens array of tokens to be approved
    /// @param pool to be approved to spend
    /// @dev needs to be done after asset deployment for router to be able to support the tokens
    function approveSpendingByPool(address[] calldata tokens, address pool) external onlyOwner {
        for (uint256 i; i < tokens.length; ++i) {
            IERC20(tokens[i]).approve(pool, type(uint256).max);
        }
    }

    /// @notice swapExactTokensForTokens swaps
    /// @param tokenPath An array of token addresses. path.length must be >= 2.
    /// @param tokenPath The first element of the path is the input token, the last element is the output token.
    /// @param poolPath An array of pool addresses. The pools where the pathTokens are contained in order.
    /// @param fromAmount the amount in
    /// @param minimumToAmount the minimum amount to get for user
    /// @param to the user to send the tokens to
    /// @param deadline the deadline to respect
    /// @return amountOut received by user
    /// @return haircut total fee charged by pool
    function swapTokensForTokens(
        address[] calldata tokenPath,
        address[] calldata poolPath,
        uint256 fromAmount,
        uint256 minimumToAmount,
        address to,
        uint256 deadline
    ) external override ensure(deadline) nonReentrant returns (uint256 amountOut, uint256 haircut) {
        require(fromAmount > 0, 'invalid from amount');
        require(tokenPath.length >= 2, 'invalid token path');
        require(poolPath.length == tokenPath.length - 1, 'invalid pool path');
        require(to != address(0), 'zero address');

        // get from token from users
        IERC20(tokenPath[0]).safeTransferFrom(address(msg.sender), address(this), fromAmount);

        (amountOut, haircut) = _swap(tokenPath, poolPath, fromAmount, to);
        require(amountOut >= minimumToAmount, 'amountOut too low');
    }

    /// @notice _swap private function. Assumes router has initial fromAmount in balance.
    /// @dev assumes tokens being swapped have been approve via the approveSpendingByPool function
    /// @param tokenPath An array of token addresses. path.length must be >= 2.
    /// @param tokenPath The first element of the path is the input token, the last element is the output token.
    /// @param poolPath An array of pool addresses. The pools where the pathTokens are contained in order.
    /// @param fromAmount the amount in
    /// @param to the user to send the tokens to
    /// @return amountOut received by user
    /// @return haircut total fee charged by pool
    function _swap(
        address[] calldata tokenPath,
        address[] calldata poolPath,
        uint256 fromAmount,
        address to
    ) internal returns (uint256 amountOut, uint256 haircut) {
        // haircut of current call
        uint256 localHaircut;
        // next from amount, starts with fromAmount in arg
        uint256 nextFromAmount = fromAmount;
        // where to send tokens on next step
        address nextTo;

        for (uint256 i; i < poolPath.length; ++i) {
            // check if we're reaching the beginning or end of the poolPath array
            if (i == 0 && poolPath.length == 1) {
                // only one element in pool path - simple swap
                nextTo = to;
            } else if (i == 0) {
                // first element of a larger than one poolPath
                nextTo = address(this);
            } else if (i < poolPath.length - 1) {
                // middle element of a larger than one poolPath
                nextTo = address(this);
                nextFromAmount = amountOut;
            } else {
                // send final swapped tokens to user
                nextTo = to;
                nextFromAmount = amountOut;
            }

            // make the swap with the correct arguments
            (amountOut, localHaircut) = IPool(poolPath[i]).swap(
                tokenPath[i],
                tokenPath[i + 1],
                nextFromAmount,
                0, // minimum amount received is ensured on calling function
                nextTo,
                type(uint256).max // deadline is ensured on calling function
            );
            // increment total haircut
            haircut += localHaircut;
        }
    }

    /**
     * @notice Quotes potential outcome of a swap given current tokenPath and poolPath,
     taking in account slippage and haircut
     * @dev To be used by frontend
     * @param tokenPath The token swap path
     * @param poolPath The token pool path
     * @param fromAmount The amount to quote
     * @return potentialOutcome The potential final amount user would receive
     * @return haircut The total haircut that would be applied
     */
    function quotePotentialSwaps(
        address[] calldata tokenPath,
        address[] calldata poolPath,
        uint256 fromAmount
    ) external view returns (uint256 potentialOutcome, uint256 haircut) {
        require(fromAmount > 0, 'invalid from amount');
        require(tokenPath.length >= 2, 'invalid token path');
        require(poolPath.length == tokenPath.length - 1, 'invalid pool path');

        // haircut of current call
        uint256 localHaircut;
        // next from amount, starts with fromAmount in arg
        uint256 nextFromAmount = fromAmount;
        // where to send tokens on next step

        for (uint256 i; i < poolPath.length; ++i) {
            // check if we're reaching the beginning or end of the poolPath array
            if (i != 0) {
                nextFromAmount = potentialOutcome;
            }

            // make the swap with the correct arguments
            (potentialOutcome, localHaircut) = IPool(poolPath[i]).quotePotentialSwap(
                tokenPath[i],
                tokenPath[i + 1],
                nextFromAmount
            );
            // increment total haircut
            haircut += localHaircut;
        }
    }
}
