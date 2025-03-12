// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import {IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";

/// @notice Functionality to call permit on any EIP-2612-compliant token
/// @author Dinari (https://github.com/dinaricrypto/sbt-peripheral/blob/main/src/common/SelfPermit.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-periphery/blob/master/contracts/base/SelfPermit.sol)
/// This function is expected to be embedded in multicalls to allow EOAs to approve a contract and call a function
/// that requires an approval in a single transaction.
abstract contract SelfPermit {
    /// @notice Permits this contract to spend a given token from `msg.sender`
    /// @dev The `spender` is always address(this).
    /// @param token The address of the token spent
    /// @param owner The address of the holder of the token
    /// @param value The amount that can be spent of token
    /// @param deadline A timestamp, the current blocktime must be less than or equal to this timestamp
    /// @param v Must produce valid secp256k1 signature from the holder along with `r` and `s`
    /// @param r Must produce valid secp256k1 signature from the holder along with `v` and `s`
    /// @param s Must produce valid secp256k1 signature from the holder along with `r` and `v`
    function selfPermit(address token, address owner, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
    {
        IERC20Permit(token).permit(owner, address(this), value, deadline, v, r, s);
    }
}
