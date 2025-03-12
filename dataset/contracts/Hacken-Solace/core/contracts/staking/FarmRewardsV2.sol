// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./../utils/Governable.sol";
import "./../interfaces/staking/IxSOLACEV1.sol";
import "./../interfaces/staking/IxsLocker.sol";
import "./../interfaces/staking/IFarmRewards.sol";
import "./../interfaces/staking/IFarmRewardsV2.sol";


/**
 * @title FarmRewardsV2
 * @author solace.fi
 * @notice Rewards farmers with [**SOLACE**](./../SOLACE).
 *
 * [FarmRewards V1](./FarmRewards) rewarded CpFarmers in [**xSOLACEV1**](./xSOLACEV1) linearly vested until May 2022. [**xSOLACEV1**](./xSOLACEV1) was deprecated for [**xsLocker**](./xsLocker) and will stop receiving rebases. FarmRewards V2 attachs on top of [FarmRewards V1](./FarmRewards) and allows farmers to early withdraw their [**xSOLACEV1**](./xSOLACEV1) and deposit it into a lock, as long as that lock ends after May 2022. This will give them staking rewards and voting power.
 *
 * FarmRewards V2 is an optional alternative to [FarmRewards V1](./FarmRewards). Each user will decide how they would like their rewards. Either way, farmers will need to pay $0.03/[**SOLACE**](./../SOLACE).
 */
contract FarmRewardsV2 is IFarmRewardsV2, ReentrancyGuard, Governable {

    /***************************************
    GLOBAL VARIABLES
    ***************************************/

    /// @notice Address of the [**SOLACE**](./../SOLACE) contract.
    address public override solace;
    /// @notice Address of the [**xSOLACEV1**](./xSOLACEV1) contract.
    address public override xsolacev1;
    /// @notice Address of the [**xsLocker**](./xsLocker) contract.
    address public override xsLocker;
    /// @notice Address of the [**FarmRewardsV1**](./FarmRewards) contrcat.
    address public override farmRewardsv1;
    /// @notice Receiver for payments.
    address public override receiver;

    /// @notice timestamp that rewards finish vesting
    uint256 constant public override VESTING_END = 1651363200; // midnight UTC before May 1, 2022

    /// @notice The ID of the user's lock.
    mapping(address => uint256) public override userLock;

    /**
     * @notice Constructs the `FarmRewards` contract.
     * @param governance_ The address of the [governor](/docs/protocol/governance).
     * @param xsolacev1_ Address of [**xSOLACEV1**](./xSOLACEV1).
     * @param receiver_ Address to send proceeds.
     */
    constructor(address governance_, address solace_, address xsolacev1_, address farmRewardsv1_, address xsLocker_, address receiver_) Governable(governance_) {
        require(solace_ != address(0x0), "zero address solace");
        require(xsolacev1_ != address(0x0), "zero address xsolacev1");
        require(farmRewardsv1_ != address(0x0), "zero address farm rewards v1");
        require(xsLocker_ != address(0x0), "zero address xslocker");
        require(receiver_ != address(0x0), "zero address receiver");
        solace = solace_;
        xsolacev1 = xsolacev1_;
        farmRewardsv1 = farmRewardsv1_;
        xsLocker = xsLocker_;
        receiver = receiver_;
        IERC20(solace_).approve(xsLocker_, type(uint256).max);
    }

    /***************************************
    VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice Calculates the amount of token in needed for an amount of [**SOLACE**](./../SOLACE) out.
     * @param tokenIn The token to pay with.
     * @param amountOut The amount of [**SOLACE**](./../SOLACE) wanted.
     * @return amountIn The amount of `tokenIn` needed.
     */
    function calculateAmountIn(address tokenIn, uint256 amountOut) external view override returns (uint256 amountIn) {
        // check token support
        require(IFarmRewards(farmRewardsv1).tokenInSupported(tokenIn), "token in not supported");
        // calculate solace out @ $0.03/SOLACE
        uint256 pricePerSolace = 3 * (10 ** (ERC20(tokenIn).decimals() - 2)); // usd/solace
        amountIn = amountOut * pricePerSolace / 1 ether;
        return amountIn;
    }

    /**
     * @notice Calculates the amount of [**SOLACE**](./../SOLACE) out for an amount of token in.
     * @param tokenIn The token to pay with.
     * @param amountIn The amount of `tokenIn` in.
     * @return amountOut The amount of [**SOLACE**](./../SOLACE) out.
     */
    function calculateAmountOut(address tokenIn, uint256 amountIn) external view override returns (uint256 amountOut) {
        // check token support
        require(IFarmRewards(farmRewardsv1).tokenInSupported(tokenIn), "token in not supported");
        // calculate solace out @ $0.03/SOLACE
        uint256 pricePerSolace = 3 * (10 ** (ERC20(tokenIn).decimals() - 2)); // usd/solace
        amountOut = amountIn * 1 ether / pricePerSolace;
        return amountOut;
    }

    /**
     * @notice The amount of [**xSOLACEV1**](./xSOLACEV1) that a farmer can purchase.
     * Does not include the amount they've already redeemed.
     * @param farmer The farmer to query.
     * @return amount The amount of [**xSOLACEV1**](./xSOLACEV1).
     */
    function purchaseableXSolace(address farmer) external view override returns (uint256 amount) {
        IFarmRewards frv1 = IFarmRewards(farmRewardsv1);
        return frv1.farmedRewards(farmer) - frv1.redeemedRewards(farmer);
    }

    /**
     * @notice The amount of [**SOLACE**](./../SOLACE) that a farmer can purchase.
     * Does not include the amount they've already redeemed.
     * @param farmer The farmer to query.
     * @return amount The amount of [**SOLACE**](./../SOLACE).
     */
    function purchaseableSolace(address farmer) external view override returns (uint256 amount) {
        IFarmRewards frv1 = IFarmRewards(farmRewardsv1);
        IxSOLACEV1 xsv1 = IxSOLACEV1(xsolacev1);
        return xsv1.xSolaceToSolace(frv1.farmedRewards(farmer) - frv1.redeemedRewards(farmer));
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
        IERC20 token = IERC20(tokenIn);
        SafeERC20.safeTransferFrom(token, msg.sender, receiver, amountIn);
        uint256 balance = token.balanceOf(address(this));
        if(balance > 0) SafeERC20.safeTransfer(token, receiver, balance);
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
        IERC20 token = IERC20(tokenIn);
        SafeERC20.safeTransferFrom(token, msg.sender, receiver, amountIn);
        uint256 balance = token.balanceOf(address(this));
        if(balance > 0) SafeERC20.safeTransfer(token, receiver, balance);
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
        IFarmRewards frv1 = IFarmRewards(farmRewardsv1);
        IxSOLACEV1 xsv1 = IxSOLACEV1(xsolacev1);
        require(frv1.tokenInSupported(tokenIn), "token in not supported");
        // calculate solace/xsolace out @ $0.03/SOLACE
        uint256 solaceOut;
        uint256 xsolaceOut;
        uint256 farmedRewards = frv1.farmedRewards(depositor);
        {
        uint256 solacePerXSolace = xsv1.xSolaceToSolace(1 ether);
        uint256 pricePerSolace = 3 * (10 ** (ERC20(tokenIn).decimals() - 2)); // usd/solace
        uint256 pricePerXSolace = pricePerSolace * solacePerXSolace / 1 ether; // usd/xsolace
        solaceOut = amountIn * 1 ether / pricePerSolace;
        xsolaceOut = amountIn * 1 ether / pricePerXSolace;
        // verify xsolace rewards
        uint256 purchaseableXSolace = farmedRewards - frv1.redeemedRewards(depositor);
        if(xsolaceOut > purchaseableXSolace) {
            xsolaceOut = purchaseableXSolace;
            actualAmountIn = xsolaceOut * pricePerXSolace / 1 ether;
            solaceOut = actualAmountIn * 1 ether / pricePerSolace;
        } else {
            actualAmountIn = amountIn;
        }
        }
        // record
        {
        address[] memory users = new address[](1);
        users[0] = depositor;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = farmedRewards - xsolaceOut;
        frv1.setFarmedRewards(users, amounts);
        frv1.returnXSolace(xsolaceOut); // send xSOLACE from v1 to v2
        }
        // reward
        {
        solaceOut = xsv1.unstake(xsolaceOut);
        uint256 xsLockID = userLock[depositor];
        IxsLocker locker = IxsLocker(xsLocker);
        if(xsLockID == 0 || !locker.exists(xsLockID)) {
            // create new lock
            xsLockID = locker.createLock(depositor, solaceOut, VESTING_END);
            userLock[depositor] = xsLockID;
        } else {
            // add to existing lock
            locker.increaseAmount(xsLockID, solaceOut);
        }
        }
        return actualAmountIn;
    }

    /***************************************
    GOVERNANCE FUNCTIONS
    ***************************************/

    /**
     * @notice Sets the recipient for proceeds.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param receiver_ The new recipient.
     */
    function setReceiver(address payable receiver_) external override onlyGovernance {
        require(receiver_ != address(0x0), "zero address receiver");
        receiver = receiver_;
        //emit ReceiverSet(receiver_);
    }

    /**
     * @notice Accepts the governance role for the FarmRewards V1 contract.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     */
    function acceptFarmRewardsV1Governance() external override onlyGovernance {
        IGovernable(farmRewardsv1).acceptGovernance();
        IFarmRewards(farmRewardsv1).setReceiver(payable(address(this)));
    }

    /**
     * @notice Sets the pending governance role for the FarmRewards V1 contract.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param newGovernor The pending new governor.
     * @param newReceiver The FarmRewardsV1 receiver.
     */
    function setFarmRewardsV1Governance(address newGovernor, address newReceiver) external override onlyGovernance {
        IGovernable(farmRewardsv1).setPendingGovernance(newGovernor);
        IFarmRewards(farmRewardsv1).setReceiver(payable(newReceiver));
    }

    /**
     * @notice Rescues tokens that may have been accidentally transferred in.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param token The token to rescue.
     * @param amount Amount of the token to rescue.
     */
    function rescueTokens(address token, uint256 amount) external override onlyGovernance {
        SafeERC20.safeTransfer(IERC20(token), receiver, amount);
    }
}
