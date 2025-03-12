// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./external/@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./external/@openzeppelin/security/ReentrancyGuard.sol";

import "./interfaces/IFastWithdraw.sol";
import "./interfaces/IController.sol";
import "./interfaces/ISpool.sol";
import "./interfaces/IVault.sol";

/**
* @param  proportionateDeposit used to know how much fees to pay
* @param userStrategyShares mapping of user address to strategy shares
*/
struct VaultWithdraw {
    uint256 proportionateDeposit;
    mapping(address => uint256) userStrategyShares;
}

/**
 * @notice Implementation of the {IFastWithdraw} interface.
 *
 * @dev
 * The Fast Withdraw contract implements the logic to withdraw user shares without
 * the need to wait for the do hard work function in Spool to be executed.
 *
 * The vault maps strategy shares to users, so the user can claim them any at time.
 * Performance fee is still paid to the vault where the shares where initially taken from.
 */
contract FastWithdraw is IFastWithdraw, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    /// @notice controller contract
    IController public immutable controller;
    /// @notice fee handler contracts, to manage the risk provider fees
    address public immutable feeHandler;
    /// @notice The Spool implementation
    ISpool public immutable spool;
    /// @notice mapping of users to vault withdraws
    mapping (address => mapping(IVault => VaultWithdraw)) userVaultWithdraw;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Sets the contract initial values
     *
     * @param _controller the controller contract
     * @param _feeHandler the fee handler contract
     * @param _spool the central spool contract
     */
    constructor(
        IController _controller,
        address _feeHandler,
        ISpool _spool
    ) {
        require(
            _controller != IController(address(0)) &&
            _feeHandler != address(0) &&
            _spool != ISpool(address(0)),
            "FastWithdraw::constructor: Controller, Fee Handler or FastWithdraw address cannot be 0"
        );

        controller = _controller;
        feeHandler = _feeHandler;
        spool = _spool;
    }

    /* ========== VIEWS ========== */

    /**
     * @notice get proportionate deposit and strategy shares for a user in vault 
     *
     * @param user user address
     * @param vault vault address
     * @param strategies chosen strategies from selected vault
     *
     * @param proportionateDeposit used to know how much fees to pay
     * @param strategyShares shares in each chosen strategy for user
     */
    function getUserVaultWithdraw(
        address user,
        IVault vault,
        address[] calldata strategies
    ) external view returns(uint256 proportionateDeposit, uint256[] memory strategyShares) {
        VaultWithdraw storage vaultWithdraw = userVaultWithdraw[user][vault];

        strategyShares = new uint256[](strategies.length);

        for (uint256 i = 0; i < strategies.length; i++) {
            strategyShares[i] = vaultWithdraw.userStrategyShares[strategies[i]];
        }

        return (vaultWithdraw.proportionateDeposit, strategyShares);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /**
     * @notice Set user-strategy shares, previously owned by the vault.
     *
     * @dev
     * Requirements:
     * - Can only be called by a vault.
     *
     * @param vaultStrategies strategies from calling vault
     * @param sharesWithdrawn shares removed from the vault 
     * @param proportionateDeposit used to know how much fees to pay
     * @param user caller of withdrawFast function in the vault
     * @param fastWithdrawParams parameters on how to execute fast withdraw
     */
    function transferShares(
        address[] calldata vaultStrategies,
        uint128[] calldata sharesWithdrawn,
        uint256 proportionateDeposit,
        address user,
        FastWithdrawParams calldata fastWithdrawParams
    )
        external
        override
        onlyVault
    {
        // save
        _saveUserShares(vaultStrategies, sharesWithdrawn, proportionateDeposit, IVault(msg.sender), user);

        // execute
        if (fastWithdrawParams.doExecuteWithdraw) {
            _executeWithdraw(user, IVault(msg.sender), vaultStrategies, fastWithdrawParams.slippages, fastWithdrawParams.swapData);
        }
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice Fast withdraw user shares for a vault.
     * @dev Called after `transferShares` has been called by the vault and the user has
     *      transfered the shares from vault to FastWithdraw contracts. Now user can execute
     *      withdraw manually for strategies that belonged to the vault at any time immidiately.
     *      When withdrawn, performance fees are paid to the vault at the same rate as standar witdraw.
     *
     * @param vault Vault where fees are paid at withdraw
     * @param strategies Array of strategy addresses to fast withdraw from
     * @param slippages Array of slippage parameters to apply when withdrawing
     * @param swapData Array containig data to swap unclaimed strategy reward tokens for underlying asset
     */
    function withdraw(
        IVault vault,
        address[] calldata strategies,
        uint256[][] calldata slippages,
        SwapData[][] calldata swapData
    )
        external
        nonReentrant
    {
        _onlyVault(address(vault));
        require(strategies.length > 0, "FastWithdraw::withdraw: No strategies");

        _executeWithdraw(msg.sender, vault, strategies, slippages, swapData);
    }

    /**
     * @notice Save user strategy shares to storage transfered from the vault
     *
     * @dev When user executes vault fast withdraw, shares ownership is transfered from the vault
     *      to the FastWithdraw contract, where fast wihdraw can be executed by the user when desired.
     *      As withdraws can use a lot of gas, storing shares supports immediate withdrawing from
     *      strategies in multiple transactions in case maximum block gas limit would be reached.
     *
     * @param vaultStrategies Array of vault strategy addresses
     * @param sharesWithdrawn Array of vault strategy share amounts transfered to the user
     * @param proportionateDeposit Amount of user initial vault deposit, to claculate the performance fees
     * @param vault Vault address of where the shares came from, required to pay the shares when actual withdraw is performed
     * @param user User to whom strategy shares are assigned
     */
    function _saveUserShares(
        address[] calldata vaultStrategies,
        uint128[] calldata sharesWithdrawn,
        uint256 proportionateDeposit,
        IVault vault,
        address user
    ) private {
        VaultWithdraw storage vaultWithdraw = userVaultWithdraw[user][vault];

        vaultWithdraw.proportionateDeposit = proportionateDeposit;
        
        for (uint256 i = 0; i < vaultStrategies.length; i++) {
            vaultWithdraw.userStrategyShares[vaultStrategies[i]] += sharesWithdrawn[i];
        }

        emit UserSharesSaved(user, address(vault));
    }

    /**
     * @notice Execute the fast widrawal for strategies.
     * @dev Called after `transferShares` has been called by the vault and the user has
     *      transfered the shares from vault to FastWithdraw contracts. Now user can execute
     *      withdraw manually for strategies that belonged to the vault at any time immidiately.
     *      When withdrawn, performance fees are paid to the vault at the same rate as standar witdraw
     *
     * @param user User performing the fast withdraw
     * @param vault Vault where performance fees will pe paid
     * @param strategies Array of strategy addresses to fast withdraw from
     * @param slippages Array of slippage parameters to apply when withdrawing
     * @param swapData Array containig data to swap unclaimed strategy reward tokens for underlying asset
     */
    function _executeWithdraw(
        address user,
        IVault vault,
        address[] calldata strategies,
        uint256[][] calldata slippages,
        SwapData[][] calldata swapData
    ) private {
        require(strategies.length == slippages.length, "FastWithdraw::_executeWithdraw: Strategies length should match slippages length");
        require(strategies.length == swapData.length, "FastWithdraw::_executeWithdraw: Strategies length should match swap data length");
        VaultWithdraw storage vaultWithdraw = userVaultWithdraw[user][vault];
        
        uint256 totalWithdrawn = 0;
        for (uint256 i = 0; i < strategies.length; i++) {
            uint256 strategyShares = vaultWithdraw.userStrategyShares[strategies[i]];

            if(strategyShares > 0) {
                totalWithdrawn += spool.fastWithdrawStrat(strategies[i], address(vault.underlying()), strategyShares, slippages[i], swapData[i]);
                vaultWithdraw.userStrategyShares[strategies[i]] = 0;
                emit StrategyWithdrawn(user, address(vault), strategies[i]);
            }
        }
        
        require(totalWithdrawn > 0, "FastWithdraw::_executeWithdraw: Nothing withdrawn");

        // pay fees to the vault if user made profit
        if (totalWithdrawn > vaultWithdraw.proportionateDeposit) {
            uint256 profit = totalWithdrawn - vaultWithdraw.proportionateDeposit;

            // take fees
            uint256 fees = _payFeesAndTransfer(vault, profit);
            totalWithdrawn -= fees;

            vaultWithdraw.proportionateDeposit = 0;
        } else {
            vaultWithdraw.proportionateDeposit -= totalWithdrawn;
        }

        vault.underlying().safeTransfer(user, totalWithdrawn);
        emit FastWithdrawExecuted(user, address(vault), totalWithdrawn);
    }

    /**
     * @dev call vault to calculate and pay fees
     */
    function _payFeesAndTransfer(
        IVault vault,
        uint256 profit
    ) private returns (uint256 fees) {
        fees = vault.payFees(profit);
        vault.underlying().safeTransfer(feeHandler, fees);
    }

    /**
     * @dev Ensures that the caller is a valid vault
     */
    function _onlyVault(address vault) private view {
        require(
            controller.validVault(vault),
            "FastWithdraw::_onlyVault: Can only be invoked by vault"
        );
    }

    /* ========== MODIFIERS ========== */

    /**
     * @dev Throws if called by a non-valid vault
     */
    modifier onlyVault() {
        _onlyVault(msg.sender);
        _;
    }
}
