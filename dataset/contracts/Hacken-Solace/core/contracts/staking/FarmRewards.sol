// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./../utils/Governable.sol";
import "./../interfaces/staking/IxSOLACE.sol";
import "./../interfaces/staking/IFarmRewards.sol";


/**
 * @title FarmRewards
 * @author solace.fi
 * @notice Rewards farmers with [**SOLACE**](./../SOLACE).
 *
 * Rewards were accumulated by farmers for participating in farms. Rewards will be unlocked linearly over six months and can be redeemed for [**SOLACE**](./../SOLACE) by paying $0.03/[**SOLACE**](./../SOLACE).
 */
contract FarmRewards is IFarmRewards, ReentrancyGuard, Governable {

    /// @notice xSOLACE Token.
    address public override xsolace;

    /// @notice receiver for payments
    address public override receiver;

    /// @notice timestamp that rewards start vesting
    uint256 constant public override VESTING_START = 1638316800; // midnight UTC before December 1, 2021

    /// @notice timestamp that rewards finish vesting
    uint256 constant public override VESTING_END = 1651363200; // midnight UTC before May 1, 2022

    uint256 public override solacePerXSolace;

    /// @notice The stablecoins that can be used for payment.
    mapping(address => bool) public override tokenInSupported;

    /// @notice Total farmed rewards of a farmer.
    mapping(address => uint256) public override farmedRewards;

    /// @notice Redeemed rewards of a farmer.
    mapping(address => uint256) public override redeemedRewards;

    /**
     * @notice Constructs the `FarmRewards` contract.
     * @param governance_ The address of the [governor](/docs/protocol/governance).
     * @param xsolace_ Address of [**xSOLACE**](./xSOLACE).
     * @param receiver_ Address to send proceeds.
     * @param solacePerXSolace_ The amount of [**SOLACE**](./../SOLACE) for one [**xSOLACE**](./xSOLACE).
     */
    constructor(address governance_, address xsolace_, address receiver_, uint256 solacePerXSolace_) Governable(governance_) {
        require(xsolace_ != address(0x0), "zero address xsolace");
        require(receiver_ != address(0x0), "zero address receiver");
        xsolace = xsolace_;
        receiver = receiver_;
        solacePerXSolace = solacePerXSolace_;
    }

    /***************************************
    VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice Calculates the amount of token in needed for an amount of [**xSOLACE**](./xSOLACE) out.
     * @param tokenIn The token to pay with.
     * @param amountOut The amount of [**xSOLACE**](./xSOLACE) wanted.
     * @return amountIn The amount of `tokenIn` needed.
     */
    function calculateAmountIn(address tokenIn, uint256 amountOut) external view override returns (uint256 amountIn) {
        // check token support
        require(tokenInSupported[tokenIn], "token in not supported");
        // calculate xsolace out @ $0.03/SOLACE
        uint256 pricePerSolace = 3 * (10 ** (ERC20(tokenIn).decimals() - 2)); // usd/solace
        uint256 pricePerXSolace = pricePerSolace * solacePerXSolace / 1 ether; // usd/xsolace
        amountIn = amountOut * pricePerXSolace / 1 ether;
        return amountIn;
    }

    /**
     * @notice Calculates the amount of [**xSOLACE**](./xSOLACE) out for an amount of token in.
     * @param tokenIn The token to pay with.
     * @param amountIn The amount of `tokenIn` in.
     * @return amountOut The amount of [**xSOLACE**](./xSOLACE) out.
     */
    function calculateAmountOut(address tokenIn, uint256 amountIn) external view override returns (uint256 amountOut) {
        // check token support
        require(tokenInSupported[tokenIn], "token in not supported");
        // calculate xsolace out @ $0.03/SOLACE
        uint256 pricePerSolace = 3 * (10 ** (ERC20(tokenIn).decimals() - 2)); // usd/solace
        uint256 pricePerXSolace = pricePerSolace * solacePerXSolace / 1 ether; // usd/xsolace
        amountOut = amountIn * 1 ether / pricePerXSolace;
        return amountOut;
    }

    /**
     * @notice The amount of [**xSOLACE**](./xSOLACE) that a farmer has vested.
     * Does not include the amount they've already redeemed.
     * @param farmer The farmer to query.
     * @return amount The amount of vested [**xSOLACE**](./xSOLACE).
     */
    function purchaseableVestedXSolace(address farmer) public view override returns (uint256 amount) {
        // solhint-disable-next-line not-rely-on-time
        uint256 timestamp = block.timestamp;
        uint256 totalRewards = farmedRewards[farmer];
        uint256 totalVestedAmount = (timestamp >= VESTING_END)
            ? totalRewards // fully vested
            : (totalRewards * (timestamp - VESTING_START) / (VESTING_END - VESTING_START)); // partially vested
        amount = totalVestedAmount - redeemedRewards[farmer];
        return amount;
    }

    /***************************************
    MUTATOR FUNCTIONS
    ***************************************/

    /**
     * @notice Deposit tokens to redeem rewards.
     * @param tokenIn The token to use as payment.
     * @param amountIn The max amount to pay.
     */
    function redeem(address tokenIn, uint256 amountIn) external override nonReentrant {
        // accounting
        amountIn = _redeem(tokenIn, amountIn, msg.sender);
        // pull tokens
        SafeERC20.safeTransferFrom(IERC20(tokenIn), msg.sender, receiver, amountIn);
    }

    /**
     * @notice Deposit tokens to redeem rewards.
     * @param tokenIn The token to use as payment.
     * @param amountIn The max amount to pay.
     * @param depositor The farmer that deposits.
     * @param deadline Time the transaction must go through before.
     * @param v secp256k1 signature
     * @param r secp256k1 signature
     * @param s secp256k1 signature
     */
    function redeemSigned(address tokenIn, uint256 amountIn, address depositor, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external override nonReentrant {
        // permit
        ERC20Permit(tokenIn).permit(depositor, address(this), amountIn, deadline, v, r, s);
        // accounting
        amountIn = _redeem(tokenIn, amountIn, depositor);
        // pull tokens
        SafeERC20.safeTransferFrom(IERC20(tokenIn), depositor, receiver, amountIn);
    }

    /**
     * @notice Redeems a farmers rewards.
     * @param tokenIn The token to use as payment.
     * @param amountIn The max amount to pay.
     * @param depositor The farmer that deposits.
     * @return actualAmountIn The amount of tokens used.
     */
    function _redeem(address tokenIn, uint256 amountIn, address depositor) internal returns (uint256 actualAmountIn) {
        // check token support
        require(tokenInSupported[tokenIn], "token in not supported");
        // calculate xsolace out @ $0.03/SOLACE
        uint256 pricePerSolace = 3 * (10 ** (ERC20(tokenIn).decimals() - 2)); // usd/solace
        uint256 pricePerXSolace = pricePerSolace * solacePerXSolace / 1 ether; // usd/xsolace
        uint256 xsolaceOut = amountIn * 1 ether / pricePerXSolace;
        // verify xsolace rewards
        uint256 vestedXSolace_ = purchaseableVestedXSolace(depositor);
        if(xsolaceOut > vestedXSolace_) {
            xsolaceOut = vestedXSolace_;
            // calculate amount in for max solace
            actualAmountIn = xsolaceOut * pricePerXSolace / 1 ether;
        } else {
            actualAmountIn = amountIn;
        }
        // reward
        SafeERC20.safeTransfer(IERC20(xsolace), depositor, xsolaceOut);
        // record
        redeemedRewards[depositor] += xsolaceOut;
        return actualAmountIn;
    }

    /***************************************
    GOVERNANCE FUNCTIONS
    ***************************************/

    /**
     * @notice Adds support for tokens. Should be stablecoins.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param tokens The tokens to add support for.
     */
    function supportTokens(address[] calldata tokens) external override onlyGovernance {
        for(uint256 i = 0; i < tokens.length; ++i) {
            address token = tokens[i];
            require(token != address(0x0), "zero address token");
            tokenInSupported[token] = true;
        }
    }

    /**
     * @notice Sets the recipient for proceeds.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param receiver_ The new recipient.
     */
    function setReceiver(address payable receiver_) external override onlyGovernance {
        require(receiver_ != address(0x0), "zero address receiver");
        receiver = receiver_;
        emit ReceiverSet(receiver_);
    }

    /**
     * @notice Returns excess [**xSOLACE**](./xSOLACE).
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param amount Amount to send. Will be sent from this contract to `receiver`.
     */
    function returnXSolace(uint256 amount) external override onlyGovernance {
        SafeERC20.safeTransfer(IERC20(xsolace), receiver, amount);
    }

    /**
     * @notice Sets the rewards that farmers have earned.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param farmers Array of farmers to set.
     * @param rewards Array of rewards to set.
     */
    function setFarmedRewards(address[] calldata farmers, uint256[] calldata rewards) external override onlyGovernance {
        require(farmers.length == rewards.length, "length mismatch");
        for(uint256 i = 0; i < farmers.length; i++) {
            farmedRewards[farmers[i]] = rewards[i];
        }
    }
}
