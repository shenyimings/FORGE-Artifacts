// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "./IProtocolConfig.sol";
import "./IFeeManager.sol";
import "./ICoreOracle.sol";

interface IBank {
    struct Bank {
        bool isListed; // Whether this market exists.
        uint8 index; // Reverse look up index for this bank.
        address hardVault;
        address softVault;
        address bToken; // The bToken to draw liquidity from.
        uint256 totalShare; // The total debt share count across all open positions.
        uint256 liqThreshold; // 85% for volatile tokens, 90% for stablecoins, base 1e4
    }

    struct Position {
        address owner; // The owner of this position.
        address collToken; // The ERC1155 token used as collateral for this position.
        address underlyingToken; // Isolated underlying collateral
        address debtToken; // Debt Token
        uint256 underlyingVaultShare; // Amount of vault share for isolated underlying coll
        uint256 collId; // The token id of Wrapper.
        uint256 collateralSize; // The amount of wrapped token for this position.
        uint256 debtShare; // The debt share of debt token for given bank.
    }

    /// The owner adds a new bank gets added to the system.
    event AddBank(
        address token,
        address bToken,
        address softVault,
        address hardVault
    );
    /// The owner sets the address of the oracle smart contract.
    event SetOracle(address oracle);
    /// The owner sets token whitelist for an Wrapped ERC1155 token.
    event SetWhitelistERC1155(address indexed token, bool ok);
    /// The owner sets token whitelist for an token.
    event SetWhitelistToken(address indexed token, bool ok);
    /// Someone lend tokens to a bank via a spell caller.
    event Lend(
        uint256 positionId,
        address caller,
        address token,
        uint256 amount
    );
    event WithdrawLend(
        uint256 positionId,
        address caller,
        address token,
        uint256 amount
    );
    /// Someone borrows tokens from a bank via a spell caller.
    event Borrow(
        uint256 positionId,
        address caller,
        address token,
        uint256 amount,
        uint256 share
    );
    /// Someone repays tokens to a bank via a spell caller.
    event Repay(
        uint256 positionId,
        address caller,
        address token,
        uint256 amount,
        uint256 share
    );
    /// Someone puts tokens as collateral via a spell caller.
    event PutCollateral(
        uint256 positionId,
        address owner,
        address caller,
        address token,
        uint256 id,
        uint256 amount
    );
    /// Someone takes tokens from collateral via a spell caller.
    event TakeCollateral(
        uint256 positionId,
        address caller,
        address token,
        uint256 id,
        uint256 amount
    );
    /// Someone calls liquidatation on a position, paying debt and taking collateral tokens.
    event Liquidate(
        uint256 positionId,
        address liquidator,
        address debtToken,
        uint256 amount,
        uint256 share,
        uint256 positionSize,
        uint256 underlyingVaultSize
    );
    event Execute(uint256 positionId, address owner);

    /// @dev Return the current position while under execution.
    function POSITION_ID() external view returns (uint256);

    /// @dev Return the current target while under execution.
    function SPELL() external view returns (address);

    /// @dev Return the current executor (the owner of the current position).
    function EXECUTOR() external view returns (address);

    function nextPositionId() external view returns (uint256);

    function config() external view returns (IProtocolConfig);

    function feeManager() external view returns (IFeeManager);

    function oracle() external view returns (ICoreOracle);

    function getBankInfo(
        address token
    ) external view returns (bool isListed, address bToken, uint256 totalShare);

    function getDebtValue(uint256 positionId) external view returns (uint256);

    function getPositionValue(
        uint256 positionId
    ) external view returns (uint256);

    function getIsolatedCollateralValue(
        uint256 positionId
    ) external view returns (uint256 icollValue);

    function getPositionInfo(
        uint256 positionId
    ) external view returns (Position memory);

    /// @dev Return current position information.
    function getCurrentPositionInfo() external view returns (Position memory);

    /// @dev Trigger interest accrual and return the current borrow balance.
    function currentPositionDebt(uint256 positionId) external returns (uint256);

    /// @dev Lend tokens from the bank.
    function lend(address token, uint256 amount) external;

    /// @dev Withdraw lent tokens from the bank.
    function withdrawLend(address token, uint256 amount) external;

    /// @dev Borrow tokens from the bank.
    function borrow(address token, uint256 amount) external returns (uint256);

    /// @dev Repays tokens to the bank.
    function repay(address token, uint256 amountCall) external;

    /// @dev Put more collateral for users.
    function putCollateral(
        address collToken,
        uint256 collId,
        uint256 amountCall
    ) external;

    /// @dev Take some collateral back.
    function takeCollateral(uint256 amount) external returns (uint256);

    /// @dev Liquidate a position.
    function liquidate(
        uint256 positionId,
        address debtToken,
        uint256 amountCall
    ) external;

    function accrue(address token) external;
}
