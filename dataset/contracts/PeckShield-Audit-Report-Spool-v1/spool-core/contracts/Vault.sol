// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./vault/VaultRestricted.sol";

import "./interfaces/ISwapData.sol";
import "./interfaces/spool/ISpoolExternal.sol";

/**
 * @notice Implementation of the {IVault} interface.
 *
 * @dev
 * All vault instances are meant to be deployed via the Controller
 * as a proxy and will not be recognizable by the Spool if they are
 * not done so.
 *
 * The vault contract is capable of supporting a single currency underlying
 * asset and deposit to multiple strategies at once, including dual-collateral
 * ones.
 *
 * The vault also supports the additional distribution of extra reward tokens as
 * an incentivization mechanism proportionate to each user's deposit amount within
 * the vhe vault.
 *
 * Vault implementation consists of following contracts:
 * 1. VaultImmutable: reads vault specific immutable variable from vault proxy contract
 * 2. VaultBase: holds vault state variables and provides some of the common vault functions
 * 3. RewardDrip: distributes vault incentivized rewards to users participating in the vault
 * 4. VaultIndexActions: implements functions to synchronize the vault with central Spool contract
 * 5. VaultRestricted: exposes functions restricted for other Spool specific contracts
 * 6. Vault: exposes unrestricted functons to interact with the core vault functionality (deposit/withdraw/claim)
 */
contract Vault is VaultRestricted {
    using SafeERC20 for IERC20;
    using Bitwise for uint256;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Sets the initial immutable values of the contract.
     *
     * @dev
     * All values have been sanitized by the controller contract, meaning
     * that no additional checks need to be applied here.
     *
     * @param _spool the spool implemenation
     * @param _controller the controller implemenation
     * @param _fastWithdraw fast withdraw implementation
     * @param _feeHandler fee handler implementation
     * @param _spoolOwner spool owner contract
     */
    constructor(
        ISpool _spool,
        IController _controller,
        IFastWithdraw _fastWithdraw,
        IFeeHandler _feeHandler,
        ISpoolOwner _spoolOwner
    )
        VaultBase(
            _spool,
            _controller,
            _fastWithdraw,
            _feeHandler
        )
        SpoolOwnable(_spoolOwner)
    {}

    /* ========== DEPOSIT ========== */

    /**
     * @notice Allows a user to perform a particular deposit to the vault.
     *
     * @dev
     * Emits a {Deposit} event indicating the amount newly deposited for index.
     *
     * Perform redeem if possible:
     * - Vault: Index has been completed (sync deposits/withdrawals)
     * - User: Claim deposit shares or withdrawn amount
     * 
     * Requirements:
     *
     * - the provided strategies must be valid
     * - the caller must have pre-approved the contract for the token amount deposited
     * - the caller cannot deposit zero value
     *
     * @param vaultStrategies strategies of this vault (verified internally)
     * @param amount amount to deposit
     * @param transferFromVault if the transfer should occur from the funds transfer(controller) address
     */
    function deposit(address[] memory vaultStrategies, uint128 amount, bool transferFromVault)
        external
        verifyStrategies(vaultStrategies)
        hasStrategies(vaultStrategies)
        redeemVaultStrategiesModifier(vaultStrategies)
        redeemUserModifier
        processLazyModifier(vaultStrategies)
        updateRewards
    {
        require(amount > 0, "NDP");

        // get next possible index to deposit
        (uint256 activeGlobalIndex, uint256 _vaultIndex) = _getAndSetActiveGlobalIndex();

        // Mark user deposited amount for active index
        vaultIndexAction[_vaultIndex].depositAmount += amount;
        userIndexAction[msg.sender][_vaultIndex].depositAmount += amount;

        // Mark vault strategies to deposit at index
        _distributeInStrats(vaultStrategies, amount, activeGlobalIndex);

        // mark that vault and user have interacted at this vault index
        _updateInteractedIndex();
        _updateUserInteractedIndex();

        // transfer user deposit to Spool
        _transferDepositToSpool(amount, transferFromVault);

        // store user deposit amount
        _addInstantDeposit(amount);
    }
    
    /**
     * @notice Distributes a deposit to the various strategies based on the allocations of the vault.
     */
    function _distributeInStrats(
        address[] memory vaultStrategies,
        uint128 amount,
        uint256 activeGlobalIndex
    ) private {
        uint128 amountLeft = amount;
        uint256 lastElement = vaultStrategies.length - 1;
        uint256 _proportions = proportions;

        for (uint256 i; i < lastElement; i++) {
            uint128 proportionateAmount = _getStrategyDepositAmount(_proportions, i, amount);
            if (proportionateAmount > 0) {
                spool.deposit(vaultStrategies[i], proportionateAmount, activeGlobalIndex);
                amountLeft -= proportionateAmount;
            }
        }

        if (amountLeft > 0) {
            spool.deposit(vaultStrategies[lastElement], amountLeft, activeGlobalIndex);
        }
    }

    /* ========== WITHDRAW ========== */

    /**
     * @notice Allows a user to withdraw their deposited funds from the vault at next possible index.
     * The withdrawal is queued for when do hard work for index is completed.
     * 
     * @dev
     * Perform redeem if possible:
     * - Vault: Index has been completed (sync deposits/withdrawals)
     * - User: Claim deposit shares or withdrawn amount
     *
     * Emits a {Withdrawal} event indicating the shares burned, index of the withdraw and the amount of funds withdrawn.
     *
     * Requirements:
     *
     * - vault must not be redistributing
     * - the provided strategies must be valid
     * - the caller must have a non-zero amount of shares to withdraw
     * - the caller must have enough shares to withdraw the specified share amount
     *
     * @param vaultStrategies strategies of this vault (verified internally)
     * @param sharesToWithdraw shares amount to withdraw
     * @param withdrawAll if all shares should be removed
     */
    function withdraw(
        address[] memory vaultStrategies,
        uint128 sharesToWithdraw,
        bool withdrawAll
    )
        external
        noReallocation
        verifyStrategies(vaultStrategies)
        redeemVaultStrategiesModifier(vaultStrategies)
        redeemUserModifier
        updateRewards
    {
        sharesToWithdraw = _withdrawShares(sharesToWithdraw, withdrawAll);

        // get next possible index to withdraw
        (uint256 activeGlobalIndex, uint256 _vaultIndex) = _getAndSetActiveGlobalIndex();

        // Reduce the user's shares by the withdrawn share amount
        userIndexAction[msg.sender][_vaultIndex].withdrawShares += sharesToWithdraw;

        // add lazy withdrawn shares to the withdraw
        uint128 totalSharesToWithdraw = sharesToWithdraw + lazyWithdrawnShares;
        vaultIndexAction[_vaultIndex].withdrawShares += totalSharesToWithdraw;

        // mark strategies in the spool contract to be withdrawn at next possible index
        _withdrawFromStrats(vaultStrategies, totalSharesToWithdraw, activeGlobalIndex);

        if (totalSharesToWithdraw > sharesToWithdraw) {
            lazyWithdrawnShares = 0;
        }

        // mark that vault and user interacted at index
        _updateInteractedIndex();
        _updateUserInteractedIndex();
    }

    /* ========== FAST WITHDRAW ========== */

    /**
     * @notice Allows a user to withdraw their deposited funds right away.
     *
     * @dev 
     * Shares belonging to the user and are sent to FaswWithdraw contract
     * where a withdraw can be executed.
     *
     * Requirements:
     *
     * - vault must not be redistributing
     * - the spool system must not be mid reallocation
     *   (started DHW and not finished, at index the reallocation was initiated)
     * - the provided strategies must be valid
     * - the sistem must not be in the middle of the reallocation
     *
     * @param vaultStrategies strategies of this vault
     * @param sharesToWithdraw shares amount to withdraw
     * @param withdrawAll if all shares should be removed
     * @param fastWithdrawParams extra parameters to perform fast withdraw
     */
    function withdrawFast(
        address[] memory vaultStrategies,
        uint128 sharesToWithdraw,
        bool withdrawAll,
        FastWithdrawParams memory fastWithdrawParams
    )
        external
        noReallocation
        noMidReallocation
        verifyStrategies(vaultStrategies)
        redeemVaultStrategiesModifier(vaultStrategies)
        redeemUserModifier
        updateRewards
    {
        sharesToWithdraw = _withdrawShares(sharesToWithdraw, withdrawAll);

        uint256 vaultShareProportion = _getVaultShareProportion(sharesToWithdraw);
        totalShares -= sharesToWithdraw;
        
        uint128[] memory strategyRemovedShares = spool.removeShares(vaultStrategies, vaultShareProportion);

        uint256 proportionateDeposit = _getUserProportionateDeposit(sharesToWithdraw);

        // transfer removed shares to fast withdraw contract
        fastWithdraw.transferShares(
            vaultStrategies,
            strategyRemovedShares,
            proportionateDeposit,
            msg.sender,
            fastWithdrawParams
        );
    }

    /**
     * @notice Allows a user to withdraw their deposited funds right away,
     * while vault is reallocating.
     * 
     * @dev
     * Shares belonging to the user and are sent to FaswWithdraw contract
     * where a withdraw can be executed.
     *
     * Requirements:
     *
     * - the provided strategies must be valid
     * - the spool system must not be mid reallocation 
     *   (started DHW and not finished, at index the reallocation was initiated)
     * - vault must be redistributing
     *
     * @param vaultStrategies strategies of this vault
     * @param sharesToWithdraw shares amount to withdraw
     * @param withdrawAll if all shares should be removed
     * @param reallocation holds helper values to remove vault strategy shares while vault is reallocating
     * @param fastWithdrawParams extra parameters to perform fast withdraw
     */
    function withdrawFastWhileReallocating(
        address[] memory vaultStrategies,
        uint128 sharesToWithdraw,
        bool withdrawAll,
        ISpool.FastWithdrawalReallocation memory reallocation,
        uint256[][] memory reallocationProportions,
        FastWithdrawParams memory fastWithdrawParams
    )
        external
        noMidReallocation
        verifyStrategies(vaultStrategies)
        redeemVaultStrategiesModifier(vaultStrategies)
        redeemUserModifier
        updateRewards
    {
        require(_isVaultRedistributing(), "RDS");

        sharesToWithdraw = _withdrawShares(sharesToWithdraw, withdrawAll);

        uint256 vaultShareProportion = _getVaultShareProportion(sharesToWithdraw);

        reallocation.depositProportions = depositProportions;

        ISpoolExternal.VaultWithdraw memory vaultWithdraw = 
            ISpoolExternal.VaultWithdraw(vaultStrategies, vaultShareProportion); 

        uint128[] memory strategyRemovedShares = 
            spool.removeSharesDuringVaultReallocation(
                vaultWithdraw,
                reallocation,
                reallocationProportions
            );

        uint256 proportionateDeposit = _getUserProportionateDeposit(sharesToWithdraw);
        totalShares -= sharesToWithdraw;

        // transfer removed shares to fast withdraw contract
        fastWithdraw.transferShares(
            vaultStrategies,
            strategyRemovedShares,
            proportionateDeposit,
            msg.sender,
            fastWithdrawParams
        );
    }

    /**
     * @notice Calculates user proportionate deposit when withdrawing and updated user deposit storage
     * @dev Checks user index action to see if user already has some withdrawn shares
     *      pending to be processed.
     *
     * @param sharesToWithdraw shares amount to withdraw
     *
     * @return User deposit amount proportionate to the amount of shares being withdrawn
     */
    function _getUserProportionateDeposit(uint128 sharesToWithdraw) private returns(uint256) {
        User storage user = users[msg.sender];
        LastIndexInteracted memory userIndexInteracted = userLastInteractions[msg.sender];

        uint128 proportionateDeposit;
        uint128 sharesAtWithdrawal = user.shares + sharesToWithdraw;

        if (userIndexInteracted.index1 > 0) {
            sharesAtWithdrawal += userIndexAction[msg.sender][userIndexInteracted.index1].withdrawShares;

            if (userIndexInteracted.index2 > 0) {
                sharesAtWithdrawal += userIndexAction[msg.sender][userIndexInteracted.index2].withdrawShares;
            }
        }

        if (sharesAtWithdrawal > sharesToWithdraw) {
            uint128 userTotalDeposit = user.activeDeposit;
            proportionateDeposit = _getProportion128(userTotalDeposit, sharesToWithdraw, sharesAtWithdrawal);
            user.activeDeposit = userTotalDeposit - proportionateDeposit;
        } else {
            proportionateDeposit = user.activeDeposit;
            user.activeDeposit = 0;
        }

        return proportionateDeposit;
    }

    /* ========== LAZY WITHDRAW ========== */

    /**
     * @notice Withdraw from the vault, without notifying the central Spool contract
     *
     * @dev
     * Next user executing deposit or withdraw with a vault, will pick up this withdrawn
     * value and notify Spool of the intended withdrawal.
     * This function makes it possible to withdraw while vault is waiting for reallocation to
     * complete, as normal withdrawing is disabeled at that time.
     * Cheaper than normal withdrawal as it doesn't loop over strategies and change strategy
     * storage.
     *
     * @param sharesToWithdraw shares amount to withdraw
     * @param withdrawAll if all shares should be removed
     */
    function withdrawLazy(uint128 sharesToWithdraw, bool withdrawAll)
        external
        redeemUserModifier
    {
        sharesToWithdraw = _withdrawShares(sharesToWithdraw, withdrawAll);

        uint256 _vaultIndex = _getLazyVaultIndex();

        userIndexAction[msg.sender][_vaultIndex].withdrawShares += sharesToWithdraw;
        lazyWithdrawnShares += sharesToWithdraw;

        _updateUserInteractedIndex();
    }

    /**
     * @notice Process shares withdrawn in a lazy way
     * @dev
     * Requirements:
     *
     * - the provided strategies must be valid
     *
     * @param vaultStrategies strategies of this vault
     */
    function processLazy(address[] memory vaultStrategies)
        external
        verifyStrategies(vaultStrategies)
        redeemVaultStrategiesModifier(vaultStrategies)
    {
        _processLazy(vaultStrategies);
    }

    function _processLazy(address[] memory vaultStrategies) private {
        bool didProcess = false;
        if (lazyWithdrawnShares > 0) {
            _processLazyWithdrawals(vaultStrategies);
            didProcess = true;
        }

        if (didProcess) {
            _updateInteractedIndex();
        }
    }

    function _processLazyWithdrawals(address[] memory vaultStrategies)
        private
        verifyStrategies(vaultStrategies)
        redeemVaultStrategiesModifier(vaultStrategies)
    {
        (uint256 activeGlobalIndex, uint256 _vaultIndex) = _getAndSetActiveGlobalIndex();

        uint128 _lazyWithdrawnShares = lazyWithdrawnShares;
        lazyWithdrawnShares = 0;

        vaultIndexAction[_vaultIndex].withdrawShares += _lazyWithdrawnShares;

        _withdrawFromStrats(vaultStrategies, _lazyWithdrawnShares, activeGlobalIndex);
    }

    function _withdrawFromStrats(address[] memory vaultStrategies, uint128 totalSharesToWithdraw, uint256 activeGlobalIndex) private {
        uint256 vaultShareProportion = _getVaultShareProportion(totalSharesToWithdraw);
        for (uint256 i; i < vaultStrategies.length; i++) {
            spool.withdraw(vaultStrategies[i], vaultShareProportion, activeGlobalIndex);
        }
    }

    /* ========== CLAIM ========== */

    /**
     * @notice Allows a user to claim their debt from the vault after withdrawn shares were processed.
     *
     * @dev
     * Fee is taken from the profit
     * Perform redeem on user demand
     *
     * Emits a {DebtClaim} event indicating the debt the user claimed.
     *
     * Requirements:
     *
     * - if `doRedeemVault` is true, the provided strategies must be valid
     * - the caller must have a non-zero debt owed
     *
     * @param doRedeemVault flag, to execute redeem for the vault (synchronize deposit/withdrawals with the system)
     * @param vaultStrategies vault stratigies
     * @param doRedeemUser flag, to execute redeem for the caller
     *
     * @return claimAmount amount of underlying asset, claimed by the caller
     */
    function claim(
        bool doRedeemVault,
        address[] memory vaultStrategies,
        bool doRedeemUser
    ) external returns (uint128 claimAmount) {
        User storage user = users[msg.sender];

        if (doRedeemVault) {
            _verifyStrategies(vaultStrategies);
            _redeemVaultStrategies(vaultStrategies);
        }

        if (doRedeemUser) {
            _redeemUser();
        }

        claimAmount = user.owed;
        require(claimAmount > 0, "CA0");

        // Calculate profit and take fees
        uint128 userWithdrawnDeposits = user.withdrawnDeposits;
        if (claimAmount > userWithdrawnDeposits) {
            user.withdrawnDeposits = 0;
            uint128 profit = claimAmount - userWithdrawnDeposits;

            uint128 feesPaid = _payFeesAndTransfer(profit);

            // Substract fees paid from claim amount
            claimAmount -= feesPaid;
        } else {
            user.withdrawnDeposits = userWithdrawnDeposits - claimAmount;
        }

        user.owed = 0;

        _underlying().safeTransfer(msg.sender, claimAmount);

        emit Claimed(msg.sender, claimAmount);
    }

    /* ========== REDEEM ========== */

    /**
     * @notice Redeem vault and user deposit and withdrawals
     *
     * Requirements:
     *
     * - the provided strategies must be valid
     *
     * @param vaultStrategies vault stratigies
     *
     * @return user shares after redeem
     */
    function redeemVaultAndUser(address[] memory vaultStrategies) external returns(uint128)
    {
        redeemVaultStrategies(vaultStrategies);
        _redeemUser();

        return users[msg.sender].shares;
    }

    /**
     * @notice Redeem vault strategy deposits and withdrawals after do hard work.
     *
     * Requirements:
     *
     * - the provided strategies must be valid
     *
     * @param vaultStrategies vault stratigies
     */
    function redeemVaultStrategies(address[] memory vaultStrategies)
        public
        verifyStrategies(vaultStrategies)
    {
        _redeemVaultStrategies(vaultStrategies);
    }

    /**
     * @notice Redeem user deposit and withdrawals
     *
     * @dev
     * Can only redeem user if vault has redeemed for the desired vault index
     */
    function redeemUser()
        external
    {
        _redeemUser();
    }

    /* ========== STRATEGY REMOVED ========== */

    function notifyStrategyRemoved(
        address[] memory vaultStrategies,
        uint256 i
    )
        external
        verifyStrategies(vaultStrategies)
        hasStrategies(vaultStrategies)
        redeemVaultStrategiesModifier(vaultStrategies)
    {
        require(
            i < vaultStrategies.length &&
            !controller.validStrategy(vaultStrategies[i]),
            "BSTR"
        );

        uint256 lastElement = vaultStrategies.length - 1;
        
        address[] memory newStrategies = new address[](lastElement);
        
        if (lastElement > 0) {
            for (uint256 j; j < lastElement; j++) {
                newStrategies[j] = vaultStrategies[j];
            }

            if (i < lastElement) {
                newStrategies[i] = vaultStrategies[lastElement];
            }

            uint256 _proportions = proportions;
            uint256 proportionsLeft = FULL_PERCENT - _proportions.get14BitUintByIndex(i);
            if (lastElement > 1 && proportionsLeft > 0) {
                if (i == lastElement) {
                    _proportions = _proportions.reset14BitUintByIndex(i);
                } else {
                    uint256 lastProportion = _proportions.get14BitUintByIndex(lastElement);
                    _proportions = _proportions.reset14BitUintByIndex(i);
                    _proportions = _proportions.set14BitUintByIndex(i, lastProportion);
                }

                uint256 newProportions = _proportions;
                
                uint256 lastNewElement = lastElement - 1;
                uint256 newProportionsLeft = FULL_PERCENT;
                for (uint256 j; j < lastNewElement; j++) {
                    uint256 propJ = _proportions.get14BitUintByIndex(j);
                    propJ = (propJ * FULL_PERCENT) / proportionsLeft;
                    newProportions = newProportions.set14BitUintByIndex(i, propJ);
                    newProportionsLeft -= propJ;
                }

                newProportions = newProportions.set14BitUintByIndex(lastNewElement, newProportionsLeft);

                proportions = newProportions;
            } else {
                proportions = FULL_PERCENT;
            }
        } else {
            proportions = 0;
        }

        _updateStrategiesHash(newStrategies);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _hasStrategies(address[] memory vaultStrategies) private pure {
        require(vaultStrategies.length > 0, "NST");
    }

    /* ========== MODIFIERS ========== */

    modifier processLazyModifier(address[] memory vaultStrategies) {
        _processLazy(vaultStrategies);
        _;
    }

    modifier hasStrategies(address[] memory vaultStrategies) {
        _hasStrategies(vaultStrategies);
        _;
    }
}