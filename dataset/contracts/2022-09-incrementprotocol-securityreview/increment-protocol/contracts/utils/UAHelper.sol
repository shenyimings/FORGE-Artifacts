// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

// contracts
import {ERC20Permit} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

// interfaces
import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IClearingHouse} from "../interfaces/IClearingHouse.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IUA} from "../interfaces/IUA.sol";
import {IUAHelper} from "../interfaces/IUAHelper.sol";

// libraries
import {SafeERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibReserve} from "../lib/LibReserve.sol";

/// @title UAHelper
/// @author webthethird
/// @notice Helps users deposit and withdraw reserve tokens for UA in fewer transactions
contract UAHelper is IUAHelper {
    using SafeERC20 for IERC20Metadata;

    /// @notice UA contract
    IUA public immutable ua;

    /// @notice ClearingHouse contract
    IClearingHouse public immutable clearingHouse;

    /// @notice Vault contract
    IVault public immutable vault;

    constructor(IUA _ua, IClearingHouse _clearingHouse) {
        ua = _ua;
        clearingHouse = _clearingHouse;
        vault = _clearingHouse.vault();
    }

    /// @notice Deposit reserve tokens to the ClearingHouse for the sender
    /// @dev Uses `permit` to approve the reserve token to be transferred by this contract using a signed message
    /// @param token Reserve token to deposit
    /// @param amount Amount of reserve tokens to deposit
    /// @param deadline Expiration timestamp for the permit signature
    /// @param v Signature v
    /// @param r Signature r
    /// @param s Signature s
    function depositReserveToken(ERC20Permit token, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        _trustlessPermit(token, msg.sender, address(this), amount, deadline, v, r, s);
        _depositReserve(token, amount);
    }

    /// @notice Deposit reserve tokens to the ClearingHouse for the sender
    /// @dev The sender must have approved this contract to transfer the reserve token
    /// @param token Reserve token to deposit
    /// @param amount Amount of reserve tokens to deposit
    function depositReserveToken(IERC20Metadata token, uint256 amount) external {
        _depositReserve(token, amount);
    }

    /// @notice Withdraw reserve tokens from the ClearingHouse for the sender
    /// @dev The sender must have approved this contract to transfer their UA via `ClearingHouse.increaseAllowance`
    /// @param token Reserve token to withdraw
    /// @param amount Amount of UA tokens to burn for reserve tokens
    function withdrawReserveToken(IERC20Metadata token, uint256 amount) external {
        // Withdraw the UA from the ClearingHouse to this contract
        clearingHouse.withdrawFrom(msg.sender, amount, ua);

        // Approve the UA contract to burn the withdrawn UA
        // slither-disable-next-line unused-return
        ua.approve(address(ua), amount);

        // Burn the UA to get the reserve token
        ua.withdraw(token, amount);

        // Convert the UA amount (18 decimals) to the token amount (e.g. with 6 decimals for USDC)
        uint256 tokenAmount = LibReserve.wadToToken(token.decimals(), amount);

        // Transfer the reserve token to the sender
        token.safeTransfer(msg.sender, tokenAmount);
    }

    function _depositReserve(IERC20Metadata token, uint256 amount) internal {
        // Transfer the reserve token from the sender to this contract
        token.safeTransferFrom(msg.sender, address(this), amount);

        // Approve UA contract to transfer the reserve token from this contract
        token.safeIncreaseAllowance(address(ua), amount);

        // Wrap the reserve token to UA
        ua.mintWithReserve(token, amount);

        // Convert the token amount (e.g. with 6 decimals for USDC) to UA amount (18 decimals)
        uint256 uaAmount = LibReserve.tokenToWad(token.decimals(), amount);

        // Approve the Vault to spend UA
        // slither-disable-next-line unused-return
        ua.approve(address(vault), uaAmount);

        // Deposit the UA to the ClearingHouse
        clearingHouse.depositFor(msg.sender, uaAmount, ua);
    }

    function _trustlessPermit(
        ERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        // Try permit() before allowance check to advance nonce if possible
        try token.permit(owner, spender, value, deadline, v, r, s) {
            return;
        } catch {
            // Permit potentially got frontran. Continue anyways if allowance is sufficient.
            if (token.allowance(owner, spender) >= value) {
                return;
            }
        }
        revert("Permit failure");
    }
}
