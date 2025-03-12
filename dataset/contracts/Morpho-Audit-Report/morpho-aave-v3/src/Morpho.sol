// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {IMorpho} from "./interfaces/IMorpho.sol";
import {IPositionsManager} from "./interfaces/IPositionsManager.sol";
import {IPool, IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPool.sol";
import {IRewardsController} from "@aave-v3-periphery/rewards/interfaces/IRewardsController.sol";

import {Types} from "./libraries/Types.sol";
import {Events} from "./libraries/Events.sol";
import {Errors} from "./libraries/Errors.sol";
import {Constants} from "./libraries/Constants.sol";

import {DelegateCall} from "@morpho-utils/DelegateCall.sol";
import {ERC20, SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20 as ERC20Permit2, Permit2Lib} from "@permit2/libraries/Permit2Lib.sol";

import {MorphoStorage} from "./MorphoStorage.sol";
import {MorphoGetters} from "./MorphoGetters.sol";
import {MorphoSetters} from "./MorphoSetters.sol";

/// @title Morpho
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice The main Morpho contract exposing all user entry points.
contract Morpho is IMorpho, MorphoGetters, MorphoSetters {
    using DelegateCall for address;
    using SafeTransferLib for ERC20;
    using Permit2Lib for ERC20Permit2;

    /* INITIALIZER */

    /// @notice Initializes the contract.
    /// @param addressesProvider The address of the pool addresses provider.
    /// @param eModeCategoryId The e-mode category of the deployed Morpho. 0 for the general mode.
    /// @param positionsManager The address of the `_positionsManager` to set.
    /// @param defaultIterations The `_defaultIterations` to set.
    function initialize(
        address addressesProvider,
        uint8 eModeCategoryId,
        address positionsManager,
        Types.Iterations memory defaultIterations
    ) external initializer {
        __Ownable_init_unchained();

        _addressesProvider = IPoolAddressesProvider(addressesProvider);
        _pool = IPool(_addressesProvider.getPool());

        _positionsManager = positionsManager;
        _defaultIterations = defaultIterations;
        emit Events.DefaultIterationsSet(defaultIterations.repay, defaultIterations.withdraw);
        emit Events.PositionsManagerSet(positionsManager);

        _eModeCategoryId = eModeCategoryId;
        _pool.setUserEMode(_eModeCategoryId);
    }

    /* EXTERNAL */

    /// @notice Supplies `amount` of `underlying` on behalf of `onBehalf`.
    ///         The supplied amount cannot be used as collateral but is eligible for the peer-to-peer matching.
    /// @param underlying The address of the underlying asset to supply.
    /// @param amount The amount of `underlying` to supply.
    /// @param onBehalf The address that will receive the supply position.
    /// @param maxIterations The maximum number of iterations allowed during the matching process. Using 4 was shown to be efficient in Morpho Labs' simulations.
    /// @return The amount supplied (in underlying).
    function supply(address underlying, uint256 amount, address onBehalf, uint256 maxIterations)
        external
        returns (uint256)
    {
        return _supply(underlying, amount, msg.sender, onBehalf, maxIterations);
    }

    /// @notice Supplies `amount` of `underlying` of `onBehalf` using permit2 in a single tx.
    ///         The supplied amount cannot be used as collateral but is eligible for the peer-to-peer matching.
    /// @param underlying The address of the `underlying` asset to supply.
    /// @param amount The amount of `underlying` to supply.
    /// @param onBehalf The address that will receive the supply position.
    /// @param maxIterations The maximum number of iterations allowed during the matching process.
    /// @param deadline The deadline for the permit2 signature.
    /// @param signature The permit2 signature.
    /// @return The amount supplied (in underlying).
    function supplyWithPermit(
        address underlying,
        uint256 amount,
        address onBehalf,
        uint256 maxIterations,
        uint256 deadline,
        Types.Signature calldata signature
    ) external returns (uint256) {
        ERC20Permit2(underlying).simplePermit2(
            msg.sender, address(this), amount, deadline, signature.v, signature.r, signature.s
        );
        return _supply(underlying, amount, msg.sender, onBehalf, maxIterations);
    }

    /// @notice Supplies `amount` of `underlying` collateral to the pool on behalf of `onBehalf`.
    ///         The supplied amount cannot be matched peer-to-peer but can be used as collateral.
    /// @param underlying The address of the underlying asset to supply.
    /// @param amount The amount of `underlying` to supply.
    /// @param onBehalf The address that will receive the collateral position.
    /// @return The collateral amount supplied (in underlying).
    function supplyCollateral(address underlying, uint256 amount, address onBehalf) external returns (uint256) {
        return _supplyCollateral(underlying, amount, msg.sender, onBehalf);
    }

    /// @notice Supplies `amount` of `underlying` collateral to the pool on behalf of `onBehalf` using permit2 in a single tx.
    ///         The supplied amount cannot be matched peer-to-peer but can be used as collateral.
    /// @param underlying The address of the underlying asset to supply.
    /// @param amount The amount of `underlying` to supply.
    /// @param onBehalf The address that will receive the collateral position.
    /// @param deadline The deadline for the permit2 signature.
    /// @param signature The permit2 signature.
    /// @return The collateral amount supplied (in underlying).
    function supplyCollateralWithPermit(
        address underlying,
        uint256 amount,
        address onBehalf,
        uint256 deadline,
        Types.Signature calldata signature
    ) external returns (uint256) {
        ERC20Permit2(underlying).simplePermit2(
            msg.sender, address(this), amount, deadline, signature.v, signature.r, signature.s
        );
        return _supplyCollateral(underlying, amount, msg.sender, onBehalf);
    }

    /// @notice Borrows `amount` of `underlying` on behalf of `onBehalf`.
    ///         If sender is not `onBehalf`, sender must have previously been approved by `onBehalf` using `approveManager`.
    /// @param underlying The address of the underlying asset to borrow.
    /// @param amount The amount of `underlying` to borrow.
    /// @param onBehalf The address that will receive the debt position.
    /// @param receiver The address that will receive the borrowed funds.
    /// @param maxIterations The maximum number of iterations allowed during the matching process. Using 4 was shown to be efficient in Morpho Labs' simulations.
    /// @return The amount borrowed (in underlying).
    function borrow(address underlying, uint256 amount, address onBehalf, address receiver, uint256 maxIterations)
        external
        returns (uint256)
    {
        return _borrow(underlying, amount, onBehalf, receiver, maxIterations);
    }

    /// @notice Repays `amount` of `underlying` on behalf of `onBehalf`.
    /// @param underlying The address of the underlying asset to borrow.
    /// @param amount The amount of `underlying` to repay.
    /// @param onBehalf The address whose position will be repaid.
    /// @return The amount repaid (in underlying).
    function repay(address underlying, uint256 amount, address onBehalf) external returns (uint256) {
        return _repay(underlying, amount, msg.sender, onBehalf);
    }

    /// @notice Repays `amount` of `underlying` on behalf of `onBehalf` using permit2 in a single tx.
    /// @dev When repaying all, one should pass `type(uint160).max` as `amount` because Permit2 does not support approvals larger than 160 bits.
    /// @param underlying The address of the underlying asset to borrow.
    /// @param amount The amount of `underlying` to repay.
    /// @param onBehalf The address whose position will be repaid.
    /// @param deadline The deadline for the permit2 signature.
    /// @param signature The permit2 signature.
    /// @return The amount repaid (in underlying).
    function repayWithPermit(
        address underlying,
        uint256 amount,
        address onBehalf,
        uint256 deadline,
        Types.Signature calldata signature
    ) external returns (uint256) {
        ERC20Permit2(underlying).simplePermit2(
            msg.sender, address(this), amount, deadline, signature.v, signature.r, signature.s
        );
        return _repay(underlying, amount, msg.sender, onBehalf);
    }

    /// @notice Withdraws `amount` of `underlying` on behalf of `onBehalf`.
    ///         If sender is not `onBehalf`, sender must have previously been approved by `onBehalf` using `approveManager`.
    /// @param underlying The address of the underlying asset to withdraw.
    /// @param amount The amount of `underlying` to withdraw.
    /// @param onBehalf The address whose position will be withdrawn.
    /// @param receiver The address that will receive the withdrawn funds.
    /// @param maxIterations The maximum number of iterations allowed during the matching process.
    ///                      If it is less than `_defaultIterations.withdraw`, the latter will be used.
    ///                      Pass 0 to fallback to the `_defaultIterations.withdraw`.
    /// @return The amount withdrawn.
    function withdraw(address underlying, uint256 amount, address onBehalf, address receiver, uint256 maxIterations)
        external
        returns (uint256)
    {
        return _withdraw(underlying, amount, onBehalf, receiver, maxIterations);
    }

    /// @notice Withdraws `amount` of `underlying` collateral on behalf of `onBehalf`.
    ///         If sender is not `onBehalf`, sender must have previously been approved by `onBehalf` using `approveManager`.
    /// @param underlying The address of the underlying asset to withdraw.
    /// @param amount The amount of `underlying` to withdraw.
    /// @param onBehalf The address whose position will be withdrawn.
    /// @param receiver The address that will receive the withdrawn funds.
    /// @return The collateral amount withdrawn (in underlying).
    function withdrawCollateral(address underlying, uint256 amount, address onBehalf, address receiver)
        external
        returns (uint256)
    {
        return _withdrawCollateral(underlying, amount, onBehalf, receiver);
    }

    /// @notice Liquidates `user`.
    /// @param underlyingBorrowed The address of the underlying borrowed to repay.
    /// @param underlyingCollateral The address of the underlying collateral to seize.
    /// @param user The address of the user to liquidate.
    /// @param amount The amount of `underlyingBorrowed` to repay.
    /// @return The `underlyingBorrowed` amount repaid (in underlying) and the `underlyingCollateral` amount seized (in underlying).
    function liquidate(address underlyingBorrowed, address underlyingCollateral, address user, uint256 amount)
        external
        returns (uint256, uint256)
    {
        return _liquidate(underlyingBorrowed, underlyingCollateral, amount, user, msg.sender);
    }

    /// @notice Approves a `manager` to borrow/withdraw on behalf of the sender.
    /// @param manager The address of the manager.
    /// @param isAllowed Whether `manager` is allowed to manage `msg.sender`'s position or not.
    function approveManager(address manager, bool isAllowed) external {
        _approveManager(msg.sender, manager, isAllowed);
    }

    /// @notice Approves a `manager` to manage the position of `msg.sender` using EIP712 signature in a single tx.
    /// @param delegator The address of the delegator.
    /// @param manager The address of the manager.
    /// @param isAllowed Whether `manager` is allowed to manage `msg.sender`'s position or not.
    /// @param nonce The nonce of the signed message.
    /// @param deadline The deadline of the signed message.
    /// @param signature The signature of the message.
    function approveManagerWithSig(
        address delegator,
        address manager,
        bool isAllowed,
        uint256 nonce,
        uint256 deadline,
        Types.Signature calldata signature
    ) external {
        if (uint256(signature.s) > Constants.MAX_VALID_ECDSA_S) revert Errors.InvalidValueS();
        // v âˆˆ {27, 28} (source: https://ethereum.github.io/yellowpaper/paper.pdf #308)
        if (signature.v != 27 && signature.v != 28) revert Errors.InvalidValueV();

        bytes32 structHash = keccak256(
            abi.encode(Constants.EIP712_AUTHORIZATION_TYPEHASH, delegator, manager, isAllowed, nonce, deadline)
        );
        bytes32 digest = _hashEIP712TypedData(structHash);
        address signatory = ecrecover(digest, signature.v, signature.r, signature.s);

        if (signatory == address(0) || delegator != signatory) revert Errors.InvalidSignatory();
        if (block.timestamp >= deadline) revert Errors.SignatureExpired();

        uint256 usedNonce = _userNonce[signatory]++;
        if (nonce != usedNonce) revert Errors.InvalidNonce();

        emit Events.UserNonceIncremented(msg.sender, signatory, usedNonce);

        _approveManager(signatory, manager, isAllowed);
    }

    /// @notice Claims rewards for the given assets.
    /// @param assets The assets to claim rewards from (aToken or variable debt token).
    /// @param onBehalf The address for which rewards are claimed and sent to.
    /// @return rewardTokens The addresses of each reward token.
    /// @return claimedAmounts The amount of rewards claimed (in reward tokens).
    function claimRewards(address[] calldata assets, address onBehalf)
        external
        returns (address[] memory rewardTokens, uint256[] memory claimedAmounts)
    {
        if (address(_rewardsManager) == address(0)) revert Errors.AddressIsZero();
        if (_isClaimRewardsPaused) revert Errors.ClaimRewardsPaused();

        (rewardTokens, claimedAmounts) = _rewardsManager.claimRewards(assets, onBehalf);
        IRewardsController(_rewardsManager.REWARDS_CONTROLLER()).claimAllRewardsToSelf(assets);

        for (uint256 i; i < rewardTokens.length; ++i) {
            uint256 claimedAmount = claimedAmounts[i];

            if (claimedAmount > 0) {
                ERC20(rewardTokens[i]).safeTransfer(onBehalf, claimedAmount);
                emit Events.RewardsClaimed(msg.sender, onBehalf, rewardTokens[i], claimedAmount);
            }
        }
    }

    /* INTERNAL */

    function _supply(address underlying, uint256 amount, address from, address onBehalf, uint256 maxIterations)
        internal
        returns (uint256)
    {
        bytes memory returnData = _positionsManager.functionDelegateCall(
            abi.encodeCall(IPositionsManager.supplyLogic, (underlying, amount, from, onBehalf, maxIterations))
        );
        return (abi.decode(returnData, (uint256)));
    }

    function _supplyCollateral(address underlying, uint256 amount, address from, address onBehalf)
        internal
        returns (uint256)
    {
        bytes memory returnData = _positionsManager.functionDelegateCall(
            abi.encodeCall(IPositionsManager.supplyCollateralLogic, (underlying, amount, from, onBehalf))
        );

        return (abi.decode(returnData, (uint256)));
    }

    function _borrow(address underlying, uint256 amount, address onBehalf, address receiver, uint256 maxIterations)
        internal
        returns (uint256)
    {
        bytes memory returnData = _positionsManager.functionDelegateCall(
            abi.encodeCall(IPositionsManager.borrowLogic, (underlying, amount, onBehalf, receiver, maxIterations))
        );

        return (abi.decode(returnData, (uint256)));
    }

    function _repay(address underlying, uint256 amount, address from, address onBehalf) internal returns (uint256) {
        bytes memory returnData = _positionsManager.functionDelegateCall(
            abi.encodeCall(IPositionsManager.repayLogic, (underlying, amount, from, onBehalf))
        );

        return (abi.decode(returnData, (uint256)));
    }

    function _withdraw(address underlying, uint256 amount, address onBehalf, address receiver, uint256 maxIterations)
        internal
        returns (uint256)
    {
        bytes memory returnData = _positionsManager.functionDelegateCall(
            abi.encodeCall(IPositionsManager.withdrawLogic, (underlying, amount, onBehalf, receiver, maxIterations))
        );

        return (abi.decode(returnData, (uint256)));
    }

    function _withdrawCollateral(address underlying, uint256 amount, address onBehalf, address receiver)
        internal
        returns (uint256)
    {
        bytes memory returnData = _positionsManager.functionDelegateCall(
            abi.encodeCall(IPositionsManager.withdrawCollateralLogic, (underlying, amount, onBehalf, receiver))
        );

        return (abi.decode(returnData, (uint256)));
    }

    function _liquidate(
        address underlyingBorrowed,
        address underlyingCollateral,
        uint256 amount,
        address borrower,
        address liquidator
    ) internal returns (uint256 repaid, uint256 seized) {
        bytes memory returnData = _positionsManager.functionDelegateCall(
            abi.encodeCall(
                IPositionsManager.liquidateLogic,
                (underlyingBorrowed, underlyingCollateral, amount, borrower, liquidator)
            )
        );

        return (abi.decode(returnData, (uint256, uint256)));
    }
}
