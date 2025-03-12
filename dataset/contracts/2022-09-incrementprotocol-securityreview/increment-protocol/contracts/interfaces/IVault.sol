// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

// interfaces
import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IInsurance} from "./IInsurance.sol";
import {IOracle} from "./IOracle.sol";
import {IClearingHouse} from "./IClearingHouse.sol";

interface IVault {
    struct Collateral {
        IERC20Metadata asset;
        uint256 weight;
        uint8 decimals;
        uint256 currentAmount;
        uint256 maxAmount;
    }

    /* ****************** */
    /*     Errors         */
    /* ****************** */

    /// @notice Emitted when the zero address is provided as a parameter in the constructor
    error Vault_ZeroAddressConstructor(uint8 paramIndex);

    /// @notice Emitted when user tries to withdraw collateral while having a UA debt
    error Vault_UADebt();

    /// @notice Emitted when the sender is not the clearing house
    error Vault_SenderNotClearingHouse();

    /// @notice Emitted when the sender is nor the insurance
    error Vault_SenderNotInsurance();

    /// @notice Emitted when a user attempts to use a token which is not whitelisted as collateral
    error Vault_UnsupportedCollateral();

    /// @notice Emitted when owner tries to whitelist a collateral already whitelisted
    error Vault_CollateralAlreadyWhiteListed();

    /// @notice Emitted when a user attempts to withdraw more than their allowance
    error Vault_WithdrawInsufficientAllowance();

    /// @notice Emitted when a user attempts to withdraw more than their balance
    error Vault_WithdrawExcessiveAmount();

    /// @notice Emitted when the proposed clearingHouse address is equal to the zero address
    error Vault_ClearingHouseZeroAddress();

    /// @notice Emitted when the clearingHouse has already been set (one time call function)
    error Vault_ClearingHouseAlreadySet();

    /// @notice Emitted when the proposed insurance address is equal to the zero address
    error Vault_InsuranceZeroAddress();

    /// @notice Emitted when the insurance has already been set (one time call function)
    error Vault_InsuranceAlreadySet();

    /// @notice Emitted when the proposed oracle address is equal to the zero address
    error Vault_OracleZeroAddress();

    /// @notice Emitted when the proposed collateral weight is under the limit
    error Vault_InsufficientCollateralWeight();

    /// @notice Emitted when the proposed collateral weight is above the limit
    error Vault_ExcessiveCollateralWeight();

    /// @notice Emitted when a user attempts to withdraw more collateral than available in vault
    error Vault_InsufficientBalance();

    /// @notice Emitted when a user attempts to withdraw more collateral than available in vault
    error Vault_MaxCollateralAmountExceeded();

    /// @notice Emitted when a user attempts to approve the zero address
    error Vault_ApproveZeroAddress();

    /* ****************** */
    /*     Events         */
    /* ****************** */

    /// @notice Emitted when a new approval value is set
    /// @param user User who made the approval
    /// @param receiver Account that was approved
    /// @param tokenIdx Index of the token that was approved
    /// @param amount Amount that the receiver is approved to use. Might not be 18 decimals
    event Approval(address indexed user, address indexed receiver, uint256 tokenIdx, uint256 amount);

    /// @notice Emitted when collateral is deposited into the vault
    /// @param user User who deposited collateral
    /// @param asset Token to be used for the collateral
    /// @param amount Amount to be used as collateral. Might not be 18 decimals
    event Deposit(address indexed user, address indexed asset, uint256 amount);

    /// @notice Emitted when collateral is withdrawn from the vault
    /// @param user User who deposited collateral
    /// @param asset Token to be used for the collateral
    /// @param amount Amount to be used as collateral. Might not be 18 decimals
    event Withdraw(address indexed user, address indexed asset, uint256 amount);

    /// @notice Emitted when bad debt is settled for by the insurance reserve
    /// @param beneficiary Beneficiary of the insurance payment
    /// @param amount Amount of bad insurance requested
    event TraderBadDebtGenerated(address beneficiary, uint256 amount);

    /// @notice Emitted when the ClearingHouse address is updated
    /// @param newClearingHouse New ClearingHouse contract address
    event ClearingHouseChanged(IClearingHouse newClearingHouse);

    /// @notice Emitted when the Insurance address is updated
    /// @param newInsurance New Insurance contract address
    event InsuranceChanged(IInsurance newInsurance);

    /// @notice Emitted when the Oracle address is updated
    /// @param newOracle New Oracle contract address
    event OracleChanged(IOracle newOracle);

    /// @notice Emitted when a new collateral is added to the Vault
    /// @param asset Asset added as collateral
    /// @param weight Volatility measure of the asset
    /// @param maxAmount weight for the collateral
    event CollateralAdded(IERC20Metadata asset, uint256 weight, uint256 maxAmount);

    /// @notice Emitted when a collateral weight is updated
    /// @param asset Asset targeted by the change
    /// @param newWeight New volatility measure for the collateral
    event CollateralWeightChanged(IERC20Metadata asset, uint256 newWeight);

    /// @notice Emitted when a collateral max amount is updated
    /// @param asset Asset targeted by the change
    /// @param newMaxAmount New max amount for the collateral
    event CollateralMaxAmountChanged(IERC20Metadata asset, uint256 newMaxAmount);

    /* ****************** */
    /*     Viewer         */
    /* ****************** */
    function insurance() external view returns (IInsurance);

    function oracle() external view returns (IOracle);

    function clearingHouse() external view returns (IClearingHouse);

    // slither-disable-next-line naming-convention
    function UA() external view returns (IERC20Metadata);

    function tokenToCollateralIdx(IERC20Metadata token) external view returns (uint256);

    function getTotalValueLocked() external view returns (int256);

    function getWhiteListedCollateral(uint256 idx) external view returns (Collateral memory);

    function getNumberOfCollaterals() external view returns (uint256);

    function getAllowance(address user, address receiver, uint256 tokenIdx) external view returns (uint256);

    function getReserveValue(address trader, bool isDiscounted) external view returns (int256);

    function getBalance(address user, uint256 tokenIdx) external view returns (int256);

    /* ****************** */
    /*  State modifying   */
    /* ****************** */

    function increaseAllowance(address user, address receiver, uint256 addedAmount, IERC20Metadata token) external;

    function decreaseAllowance(address user, address receiver, uint256 subtractedAmount, IERC20Metadata token)
        external;

    function deposit(address sender, address user, uint256 amount, IERC20Metadata token) external;

    function settlePnL(address user, int256 amount) external;

    function withdraw(address user, uint256 amount, IERC20Metadata token) external;

    function withdrawAll(address user, IERC20Metadata withdrawToken) external;

    function withdrawFrom(address user, address receiver, uint256 amount, IERC20Metadata token) external;

    function settleLiquidationOnCollaterals(address liquidator, address liquidatee) external;

    function transferUa(address user, uint256 amount) external;

    /* ****************** */
    /*     Governance     */
    /* ****************** */

    function setClearingHouse(IClearingHouse newClearingHouse) external;

    function setInsurance(IInsurance newInsurance) external;

    function setOracle(IOracle newOracle) external;

    function addWhiteListedCollateral(IERC20Metadata asset, uint256 weight, uint256 maxAmount) external;

    function changeCollateralWeight(IERC20Metadata asset, uint256 newWeight) external;

    function changeCollateralMaxAmount(IERC20Metadata asset, uint256 newMaxAmount) external;
}
