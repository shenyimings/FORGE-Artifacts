// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";

import {Constants as C} from "../../lib/Constants.sol";
import {ILendingPool} from "../../interfaces/aave-v2/ILendingPool.sol";
import {IProtocolDataProvider} from "../../interfaces/aave-v2/IProtocolDataProvider.sol";
import {IAdapter} from "../IAdapter.sol";

/**
 * @title Aave v2 Lending Protocol Adapter
 * @notice Facilitates lending and borrowing for the Aave v2 lending protocol
 */
contract AaveV2Adapter is IAdapter {
    ERC20 constant usdc = ERC20(C.USDC);
    WETH constant weth = WETH(payable(C.WETH));

    // Aave v2 lending pool
    ILendingPool public constant pool = ILendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    // Aave v2 protocol data provider
    IProtocolDataProvider public constant aaveV2ProtocolDataProvider =
        IProtocolDataProvider(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d);
    // Aave v2 interest bearing USDC (aUSDC) token
    ERC20 public constant aUsdc = ERC20(0xBcca60bB61934080951369a648Fb03DF4F96263C);
    // Aave v2 variable debt bearing WETH (variableDebtWETH) token
    ERC20 public constant dWeth = ERC20(0xF63B34710400CAd3e044cFfDcAb00a0f32E33eCf);

    /// @inheritdoc IAdapter
    uint256 public constant override id = 2;

    /// @inheritdoc IAdapter
    function setApprovals() external override {
        usdc.approve(address(pool), type(uint256).max);
        weth.approve(address(pool), type(uint256).max);
    }

    /// @inheritdoc IAdapter
    function revokeApprovals() external override {
        usdc.approve(address(pool), 0);
        weth.approve(address(pool), 0);
    }

    /// @inheritdoc IAdapter
    function supply(uint256 _amount) external override {
        pool.deposit(address(usdc), _amount, address(this), 0);
    }

    /// @inheritdoc IAdapter
    function borrow(uint256 _amount) external override {
        pool.borrow(address(weth), _amount, C.AAVE_VAR_INTEREST_RATE_MODE, 0, address(this));
    }

    /// @inheritdoc IAdapter
    function repay(uint256 _amount) external override {
        pool.repay(address(weth), _amount, C.AAVE_VAR_INTEREST_RATE_MODE, address(this));
    }

    /// @inheritdoc IAdapter
    function withdraw(uint256 _amount) external override {
        pool.withdraw(address(usdc), _amount, address(this));
    }

    /// @inheritdoc IAdapter
    function claimRewards(bytes calldata) external pure override {
        revert("not applicable");
    }

    /// @inheritdoc IAdapter
    function getCollateral(address _account) external view override returns (uint256) {
        return aUsdc.balanceOf(_account);
    }

    /// @inheritdoc IAdapter
    function getDebt(address _account) external view override returns (uint256) {
        return dWeth.balanceOf(_account);
    }

    /// @inheritdoc IAdapter
    function getMaxLtv() external view virtual override returns (uint256) {
        (, uint256 ltv,,,,,,,,) = aaveV2ProtocolDataProvider.getReserveConfigurationData(address(usdc));

        // ltv is returned as a percentage with 2 decimals (e.g. 80% = 8000) so we need to multiply by 1e14
        return ltv * 1e14;
    }
}
