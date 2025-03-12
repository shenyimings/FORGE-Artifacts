// SPDX-License-Identifier: Unlicensed
pragma solidity >=0.8.0 <0.9.0;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin/utils/Address.sol";
import "openzeppelin/utils/math/SafeCast.sol";
import "openzeppelin/utils/Strings.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IBalancer.sol";
import "../helpers/SwapExecutor.sol";


abstract contract BaseAdapter is IAdapter {
    using SafeERC20 for IERC20;

    address public immutable BALANCER;
    SwapExecutor public immutable SWAP_EXECUTOR;

    modifier onlyBalancer {
        require(msg.sender == BALANCER);
        _;
    }

    constructor(address balancer) {
        BALANCER = balancer;
        SWAP_EXECUTOR = SwapExecutor(IBalancer(balancer).swapExecutor());
    }

    function invest(address dustReceiver)
        external
        virtual
        override
        onlyBalancer
        returns (uint256 valueBefore, uint256 valueAfter)
    {
        (valueBefore, valueAfter) = _investInternal(dustReceiver);
    }

    function redeem(uint256 lpAmount, address to)
        external
        virtual
        override
        onlyBalancer
        returns (address[] memory tokens, uint256[] memory amounts)
    {
        (tokens, amounts) = _redeem(lpAmount, to);
    }

    function compound(IBalancer.SwapInfo[] calldata swaps)
        external
        virtual
        override
        onlyBalancer
        returns (uint256 valueBefore, uint256 valueAfter)
    {
        _claimAll();

        for (uint i = 0; i < swaps.length; ++i) {
            IBalancer.SwapInfo calldata swap = swaps[i];
            IERC20(swap.token).safeTransfer(address(SWAP_EXECUTOR), swap.amount);
        }
        SWAP_EXECUTOR.executeSwaps(swaps);

        (valueBefore, valueAfter) = _investInternal(address(BALANCER));
    }

    function recoverFunds(IBalancer.TransferInfo calldata transfer, address to) 
        external 
        virtual 
        override 
        onlyBalancer
    {
        address[] memory tokens = negotiableTokens();
        for (uint i = 0; i < tokens.length; i++) {
            if (tokens[i] == transfer.token) {
                revert UnsupportedToken(transfer.token);
            }
        }
        IERC20(transfer.token).safeTransfer(to, transfer.amount);
    }

    /// @notice Execute calls by the adapter to reallocate funds to other adapter if external api used in the adapter is changed
    /// @dev Calls must be executed by timelock
    function emergencyCall(CallInfo[] calldata calls)
        external
        virtual
        override
        onlyBalancer
    {
        for (uint i = 0; i < calls.length; i++) {
            CallInfo calldata call = calls[i];
            Address.functionCall(call.callee, call.data);
        }
    }

    function _investInternal(address dustReceiver) internal returns (uint256 valueBefore, uint256 valueAfter) {
        (valueBefore,) = value();
        _invest();
        (valueAfter,) = value();
        _returnDust(dustReceiver);
    }

    function _returnDust(address dustReceiver) internal {
        address[] memory tokens = depositTokens();
        uint tokensLength = tokens.length;

        for (uint i = 0; i < tokensLength; ++i) {
            IERC20 token = IERC20(tokens[i]);
            uint256 tokenBalance = token.balanceOf(address(this));

            if (tokenBalance > 0) {
                SafeERC20.safeTransfer(token, dustReceiver, tokenBalance);
            }
        }
    }

    function _invest() internal virtual;
    function _redeem(uint256 lpAmount, address to)
        internal
        virtual
        returns (address[] memory tokens, uint[] memory amounts);
    function _claimAll() internal virtual;
    function negotiableTokens() public virtual returns(address[] memory tokens);
    function depositTokens() public virtual view returns (address[] memory tokens);
    function value() public view virtual returns (uint estimatedValue, uint lpAmount);
    function pendingRewards() external view virtual returns(address[] memory tokens, uint[] memory amounts);
    function ratios() external view virtual returns(address[] memory tokens, uint[] memory ratio);
    function description() external virtual returns (string memory);

}