// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.23;

/*
 ██████╗ █████╗ ██╗   ██╗██╗        ██████╗ █████╗ ██╗     ██╗██████╗ ██╗████████╗██╗   ██╗
██╔════╝██╔══██╗██║   ██║██║       ██╔════╝██╔══██╗██║     ██║██╔══██╗██║╚══██╔══╝╚██╗ ██╔╝
╚█████╗ ██║  ██║██║   ██║██║       ╚█████╗ ██║  ██║██║     ██║██║  ██║██║   ██║    ╚████╔╝ 
 ╚═══██╗██║  ██║██║   ██║██║        ╚═══██╗██║  ██║██║     ██║██║  ██║██║   ██║     ╚██╔╝  
██████╔╝╚█████╔╝╚██████╔╝███████╗  ██████╔╝╚█████╔╝███████╗██║██████╔╝██║   ██║      ██║   
╚═════╝  ╚════╝  ╚═════╝ ╚══════╝  ╚═════╝  ╚════╝ ╚══════╝╚═╝╚═════╝ ╚═╝   ╚═╝      ╚═╝   

 * Twitter: https://twitter.com/SoulSolidity
 *  GitHub: https://github.com/SoulSolidity
 *     Web: https://SoulSolidity.com
 */

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ITransferHelper} from "../utils/ITransferHelper.sol";
import {IWETH} from "../lib/IWETH.sol";

contract TransferHelper is ITransferHelper {
    using SafeERC20 for IERC20;

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    IWETH public immutable WNATIVE;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(IWETH wnative) {
        WNATIVE = wnative;
    }

    /// -----------------------------------------------------------------------
    /// Wrapped Native helpers
    /// -----------------------------------------------------------------------

    /// @notice Wrap the msg.value into the Wrapped Native token
    /// @return wNative The IERC20 representation of the wrapped asset
    /// @return amount Amount of native tokens wrapped
    function _wrapNative() internal returns (IERC20 wNative, uint256 amount) {
        wNative = IERC20(address(WNATIVE));
        amount = msg.value;
        WNATIVE.deposit{value: amount}();
    }

    /// @notice Unwrap current balance of Wrapped Native tokens
    /// @return amount Amount of native tokens unwrapped
    function _unwrapNative() internal returns (uint256 amount) {
        amount = _getBalance(IERC20(address(WNATIVE)));
        IWETH(WNATIVE).withdraw(amount);
    }

    /// -----------------------------------------------------------------------
    /// ERC20 transfer helpers (supporting fee on transfer)
    /// - Also `_transferOut` WNative unwrap support.
    /// -----------------------------------------------------------------------

    /// @notice Transfers in ERC20 tokens from the sender to this contract
    /// @param token The ERC20 token to transfer
    /// @param amount The amount of tokens to transfer
    /// @return amountIn The actual amount of tokens transferred

    function _transferIn(IERC20 token, uint256 amount) internal returns (uint256 amountIn) {
        if (amount == 0) return 0;
        uint256 balanceBefore = _getBalance(token);
        token.safeTransferFrom(msg.sender, address(this), amount);
        amountIn = _getBalance(token) - balanceBefore;
    }

    /// @notice Transfers out ERC20 tokens from this contract to a recipient
    /// @param token The ERC20 token to transfer
    /// @param amount The amount of tokens to transfer
    /// @param to The recipient of the tokens
    /// @param native Whether to unwrap Wrapped Native tokens before transfer
    function _transferOut(IERC20 token, uint256 amount, address to, bool native) internal {
        if (amount == 0) return;
        if (address(token) == address(WNATIVE) && native) {
            IWETH(WNATIVE).withdraw(amount);
            // 2600 COLD_ACCOUNT_ACCESS_COST plus 2300 transfer gas - 1
            // Intended to support transfers to contracts, but not allow for further code execution
            (bool success, ) = to.call{value: amount, gas: 4899}("");
            require(success, "native transfer error");
        } else {
            token.safeTransfer(to, amount);
        }
    }

    /// @notice Gets the balance of an ERC20 token in this contract
    /// @param token The ERC20 token to check the balance of
    /// @return balance The balance of the tokens in this contract
    function _getBalance(IERC20 token) internal view returns (uint256 balance) {
        balance = token.balanceOf(address(this));
    }

    /// @notice Gets the balance of an ERC20 token in this contract
    /// @param token The ERC20 token to check the balance of
    /// @param token The address to check the balance of
    /// @return balance The balance of the tokens in this contract
    function _getBalance(IERC20 token, address _address) internal view returns (uint256 balance) {
        balance = token.balanceOf(_address);
    }
}
