// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {IWETH} from "src/interfaces/extensions/IWETH.sol";
import {IMorpho} from "src/interfaces/IMorpho.sol";
import {IWETHGateway} from "src/interfaces/extensions/IWETHGateway.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

/// @title WETHGateway
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice A contract allowing to wrap and unwrap ETH when interacting with Morpho.
contract WETHGateway is IWETHGateway {
    using SafeTransferLib for ERC20;

    /* ERRORS */

    /// @notice Thrown when another address than WETH sends ETH to the contract.
    error OnlyWETH();

    /// @notice Thrown when the `morpho` address passed in the constructor is zero.
    error AddressIsZero();

    /// @notice Thrown when the amount used is zero.
    error AmountIsZero();

    /* CONSTANTS */

    /// @dev The address of the WETH contract.
    address internal constant _WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @dev The address of the Morpho DAO.
    address internal constant _MORPHO_DAO = 0xcBa28b38103307Ec8dA98377ffF9816C164f9AFa;

    /* IMMUTABLES */

    /// @dev The address of the Morpho protocol.
    IMorpho internal immutable _MORPHO;

    /* CONSTRUCTOR */

    /// @notice Contract constructor.
    /// @param morpho The address of the Morpho protocol.
    constructor(address morpho) {
        if (morpho == address(0)) revert AddressIsZero();

        _MORPHO = IMorpho(morpho);
        ERC20(_WETH).safeApprove(morpho, type(uint256).max);
    }

    /* EXTERNAL */

    /// @notice Returns the address of the WETH contract.
    function WETH() external pure returns (address) {
        return _WETH;
    }

    /// @notice Returns the address of the Morpho protocol.
    function MORPHO() external view returns (address) {
        return address(_MORPHO);
    }

    /// @notice Returns the address of the Morpho DAO.
    function MORPHO_DAO() external pure returns (address) {
        return _MORPHO_DAO;
    }

    /// @notice Transfers this contract's given ERC20 balance to the Morpho DAO, to avoid having funds stuck.
    function skim(address underlying) external {
        ERC20(underlying).safeTransfer(_MORPHO_DAO, ERC20(underlying).balanceOf(address(this)));
    }

    /// @notice Wraps `msg.value` ETH in WETH and supplies them to Morpho on behalf of `onBehalf`.
    /// @return The actual amount supplied (in wei).
    function supplyETH(address onBehalf, uint256 maxIterations) external payable returns (uint256) {
        _wrapETH(msg.value);

        return _MORPHO.supply(_WETH, msg.value, onBehalf, maxIterations);
    }

    /// @notice Wraps `msg.value` ETH in WETH and supplies them as collateral to Morpho on behalf of `onBehalf`.
    /// @return The actual amount supplied as collateral (in wei).
    function supplyCollateralETH(address onBehalf) external payable returns (uint256) {
        _wrapETH(msg.value);

        return _MORPHO.supplyCollateral(_WETH, msg.value, onBehalf);
    }

    /// @notice Borrows WETH on behalf of `msg.sender`, unwraps the ETH and sends them to `receiver`.
    ///         Note: `msg.sender` must have approved this contract to be its manager.
    /// @return borrowed The actual amount borrowed (in wei).
    function borrowETH(uint256 amount, address receiver, uint256 maxIterations) external returns (uint256 borrowed) {
        borrowed = _MORPHO.borrow(_WETH, amount, msg.sender, address(this), maxIterations);
        _unwrapAndTransferETH(borrowed, receiver);
    }

    /// @notice Wraps `msg.value` ETH in WETH and repays `onBehalf`'s debt on Morpho.
    /// @return repaid The actual amount repaid (in wei).
    function repayETH(address onBehalf) external payable returns (uint256 repaid) {
        _wrapETH(msg.value);

        repaid = _MORPHO.repay(_WETH, msg.value, onBehalf);

        uint256 excess = msg.value - repaid;
        if (excess > 0) _unwrapAndTransferETH(excess, msg.sender);
    }

    /// @notice Withdraws WETH up to `amount` on behalf of `msg.sender`, unwraps it to WETH and sends it to `receiver`.
    ///         Note: `msg.sender` must have approved this contract to be its manager.
    /// @return withdrawn The actual amount withdrawn (in wei).
    function withdrawETH(uint256 amount, address receiver, uint256 maxIterations)
        external
        returns (uint256 withdrawn)
    {
        withdrawn = _MORPHO.withdraw(_WETH, amount, msg.sender, address(this), maxIterations);
        _unwrapAndTransferETH(withdrawn, receiver);
    }

    /// @notice Withdraws WETH as collateral up to `amount` on behalf of `msg.sender`, unwraps it to WETH and sends it to `receiver`.
    ///         Note: `msg.sender` must have approved this contract to be its manager.
    /// @return withdrawn The actual collateral amount withdrawn (in wei).
    function withdrawCollateralETH(uint256 amount, address receiver) external returns (uint256 withdrawn) {
        withdrawn = _MORPHO.withdrawCollateral(_WETH, amount, msg.sender, address(this));
        _unwrapAndTransferETH(withdrawn, receiver);
    }

    /// @dev Only the WETH contract is allowed to transfer ETH to this contracts.
    receive() external payable {
        if (msg.sender != _WETH) revert OnlyWETH();
    }

    /* INTERNAL */

    /// @dev Wraps `amount` of ETH to WETH.
    function _wrapETH(uint256 amount) internal {
        if (amount == 0) revert AmountIsZero();
        IWETH(_WETH).deposit{value: amount}();
    }

    /// @dev Unwraps `amount` of WETH to ETH and transfers it to `receiver`.
    function _unwrapAndTransferETH(uint256 amount, address receiver) internal {
        if (amount == 0) revert AmountIsZero();
        IWETH(_WETH).withdraw(amount);
        SafeTransferLib.safeTransferETH(receiver, amount);
    }
}
