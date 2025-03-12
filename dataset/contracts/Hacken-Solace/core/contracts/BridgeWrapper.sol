// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "./interfaces/ISOLACE.sol";
import "./interfaces/IBridgeWrapper.sol";


/**
 * @title Bridge Wrapper
 * @author solace.fi
 * @notice Facilitates cross chain apps by wrapping and unwrapping bridged tokens.
 *
 * Users will start by bridging [**SOLACE**](./SOLACE) from mainnet to altnets. The bridge operates the token contract on the altnet, referred to as **Bridged SOLACE** or **bSOLACE**. This contract must be used to 1:1 convert **bSOLACE** to [**SOLACE**](./SOLACE) before it can be used. This is to maintain a "native" [**SOLACE**](./SOLACE) contract that has the same address on each chain.
 *
 * Users can send [**SOLACE**](./SOLACE) back to mainnet by converting it to **bSOLACE** then using the bridge. This conversion will fail if there is insufficient bridge liquidity. The user will receive [**SOLACE**](./SOLACE) on mainnet, no unwrapping is required.
 *
 * By convention we say that **bSOLACE** is wrapped and [**SOLACE**](./SOLACE) is unwrapped.
 *
 * "Bridge Liquidity" is the measurement of how much **bSOLACE** has been converted into [**SOLACE**](./SOLACE) minus the amount of [**SOLACE**](./SOLACE) that has been converted into **bSOLACE**, which is equal to the amount of **bSOLACE** owned by this contract. Converting [**SOLACE**](./SOLACE) to **bSOLACE** will fail if it drops the bridge liquidity below zero.
 *
 * The [**SOLACE**](./SOLACE) and **bSOLACE** addresses are set on construction and cannot be modified.
 */
contract BridgeWrapper is IBridgeWrapper {

    /***************************************
    GLOBAL VARIABLES
    ***************************************/

    /// @notice [**SOLACE**](./SOLACE) token.
    address public override solace;
    /// @notice **bSOLACE** token.
    address public override bsolace;

    /**
     * @notice Constructs the Bridge Wrapper contract.
     * @param solace_ [**SOLACE**](./SOLACE) token.
     * @param bsolace_ **bSOLACE** token.
     */
    constructor(address solace_, address bsolace_) {
        require(solace_ != address(0x0), "zero address solace");
        require(bsolace_ != address(0x0), "zero address bsolace");
        solace = solace_;
        bsolace = bsolace_;
    }

    /***************************************
    UNWRAPPER FUNCTIONS (BSOLACE -> SOLACE)
    ***************************************/

    /**
     * @notice Converts **bSOLACE** to [**SOLACE**](./SOLACE).
     * @dev Uses ERC20 approve-transfer.
     * @param amount Amount of **bSOLACE** to convert.
     * @param receiver User that will receive [**SOLACE**](./SOLACE).
     */
    function bsolaceToSolace(uint256 amount, address receiver) external override {
        // pull bsolace
        SafeERC20.safeTransferFrom(IERC20(bsolace), msg.sender, address(this), amount);
        // mint solace
        ISOLACE(solace).mint(receiver, amount);
        emit Unwrapped(msg.sender, receiver, amount);
    }

    /***************************************
    WRAPPER FUNCTIONS (SOLACE -> BSOLACE)
    ***************************************/

    /**
     * @notice Converts [**SOLACE**](./SOLACE) to **bSOLACE**.
     * This conversion will fail if there is insufficient bridge liquidity.
     * @dev Uses ERC20 approve-transfer.
     * @param amount Amount of [**SOLACE**](./SOLACE) to convert.
     * @param receiver User that will receive **bSOLACE**.
     */
    function solaceToBSolace(uint256 amount, address receiver) external override {
        // pull solace
        SafeERC20.safeTransferFrom(IERC20(solace), msg.sender, address(this), amount);
        // accounting
        _solaceToBSolace(amount, receiver);
    }

    /**
     * @notice Converts [**SOLACE**](./SOLACE) to **bSOLACE**.
     * This conversion will fail if there is insufficient bridge liquidity.
     * @dev Uses ERC20 permit-transfer.
     * @param amount Amount of [**SOLACE**](./SOLACE) to convert.
     * @param receiver User that will receive **bSOLACE**.
     * @param deadline Time the transaction must go through before.
     * @param v secp256k1 signature
     * @param r secp256k1 signature
     * @param s secp256k1 signature
     */
    function solaceToBSolaceSigned(uint256 amount, address receiver, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external override {
        // permit
        IERC20Permit(solace).permit(msg.sender, address(this), amount, deadline, v, r, s);
        // pull solace
        SafeERC20.safeTransferFrom(IERC20(solace), msg.sender, address(this), amount);
        // accounting
        _solaceToBSolace(amount, receiver);
    }

    /**
     * @notice Converts [**SOLACE**](./SOLACE) to **bSOLACE**.
     * This conversion will fail if there is insufficient bridge liquidity.
     * @param amount Amount of [**SOLACE**](./SOLACE) to convert.
     * @param receiver User that will receive **bSOLACE**.
     */
    function _solaceToBSolace(uint256 amount, address receiver) internal {
        // bsolace
        IERC20 bsolace_ = IERC20(bsolace);
        require(bsolace_.balanceOf(address(this)) >= amount, "insufficient bridge liquidity");
        SafeERC20.safeTransfer(bsolace_, receiver, amount);
        // solace
        ISOLACE(solace).burn(amount);
        emit Wrapped(msg.sender, receiver, amount);
    }
}
