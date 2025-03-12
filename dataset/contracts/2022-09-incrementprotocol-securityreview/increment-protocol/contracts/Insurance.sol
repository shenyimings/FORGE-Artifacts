// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

// contracts
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {IncreAccessControl} from "./utils/IncreAccessControl.sol";

// interfaces
import {IERC20Metadata} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IInsurance} from "./interfaces/IInsurance.sol";
import {IClearingHouse} from "./interfaces/IClearingHouse.sol";

// libraries
import {LibMath} from "./lib/LibMath.sol";

/// @notice Pays out Vault in case of default
contract Insurance is IInsurance, IncreAccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;
    using LibMath for int256;
    using LibMath for uint256;

    /// @notice Insurance token
    IERC20Metadata public token;

    /// @notice Vault contract
    IVault public vault;

    /// @notice ClearingHouse contract
    IClearingHouse public clearingHouse;

    /// @notice Debt which could not be settled by insurance
    uint256 public systemBadDebt;
    bool internal isClearingHouseSet;

    constructor(IERC20Metadata _token, IVault _vault) {
        if (address(_token) == address(0)) revert Insurance_ZeroAddressConstructor(0);
        if (address(_vault) == address(0)) revert Insurance_ZeroAddressConstructor(1);
        token = _token;
        vault = _vault;
    }

    modifier onlyVault() {
        if (msg.sender != address(vault)) revert Insurance_SenderNotVault();
        _;
    }

    modifier onlyClearingHouse() {
        if (msg.sender != address(clearingHouse)) revert Insurance_SenderNotClearingHouse();
        _;
    }

    /* ********************** */
    /*   External functions   */
    /* ********************** */

    /// @notice Fund insurance. In case of bad debt, first recapitalize the Vault.
    /// @param amount Amount of UA tokens to be transfered
    function fundInsurance(uint256 amount) external override onlyClearingHouse {
        _fundInsurance(amount);
    }

    /// @notice Settle bad debt in the Vault (in UA)
    /// @notice `settleDebt` won't revert if the Insurance balance isn't large enough to cover the debt `amount`,
    ///         so from the point of view of the Vault it'll seem like the Insurance paid back the debt (while it's not).
    ///         Yet Insurance will keep track of this accounting imbalance with the `systemBadDebt` variable.
    ///         The first action of the Insurance will be to spur this debt before adding new funds to the Insurance
    ///         balance (see `fundInsurance`).
    /// @dev The UA amount transferred to the Vault is not assigned to any user's balance because the Vault cancels
    ///      the debt of the individual user when calling `settleDebt` (see `settleLiquidationOnCollaterals`).
    /// @param amount Amount of tokens withdrawn for settlement
    function settleDebt(uint256 amount) external override onlyVault {
        // only borrower
        uint256 insurBalance = IERC20Metadata(token).balanceOf(address(this));

        uint256 amountSettled;
        if (amount > insurBalance) {
            amountSettled = insurBalance;
            systemBadDebt += amount - insurBalance;
            emit SystemDebtChanged(systemBadDebt);
        } else {
            amountSettled = amount;
        }

        IERC20Metadata(token).safeTransfer(address(vault), amountSettled);
    }

    /* ****************** */
    /*     Governance     */
    /* ****************** */

    /// @notice Update the ClearingHouse
    /// @param newClearingHouse Address of the new ClearingHouse
    function setClearingHouse(IClearingHouse newClearingHouse) external onlyRole(GOVERNANCE) {
        if (address(newClearingHouse) == address(0)) revert Insurance_ClearingHouseZeroAddress();
        if (isClearingHouseSet) revert Insurance_ClearingHouseAlreadySet();

        clearingHouse = newClearingHouse;
        isClearingHouseSet = true;

        emit ClearingHouseChanged(newClearingHouse);
    }

    /// @notice Withdraw some amount from the Insurance
    /// @param amount UA amount to withdraw from the Insurance
    function removeInsurance(uint256 amount) external override onlyRole(GOVERNANCE) {
        // check insurance ratio after withdrawal
        int256 tvl = vault.getTotalValueLocked();
        uint256 lockedInsurance = token.balanceOf(address(this));

        if (
            (systemBadDebt > 0) || (lockedInsurance <= amount)
                || (lockedInsurance - amount).toInt256() < tvl.wadMul(clearingHouse.insuranceRatio().toInt256())
        ) revert Insurance_InsufficientInsurance();

        // withdraw
        emit InsuranceRemoved(amount);
        IERC20Metadata(token).safeTransfer(msg.sender, amount);
    }

    /* ********************* */
    /*  Internal functions   */
    /* ********************* */

    /// @dev If systemBadDebt - a measure of the imbalance between the quantity of UA available
    ///      in the Vault and the amount of UA claims - is positive, then leave the fee (in UA) meant for
    ///      the Insurance in the Vault.
    ///      If the Vault is fully solvent in UA terms (systemDebt < 0), then transfer UA to the Insurance.
    function _fundInsurance(uint256 amount) internal {
        if (systemBadDebt > 0) {
            if (amount > systemBadDebt) {
                uint256 excessUAAfterDebtPayBack = amount - systemBadDebt;
                vault.transferUa(address(this), excessUAAfterDebtPayBack);

                systemBadDebt = 0;
            } else {
                systemBadDebt -= amount;
            }

            emit SystemDebtChanged(systemBadDebt);
        } else {
            vault.transferUa(address(this), amount);
        }
    }
}
