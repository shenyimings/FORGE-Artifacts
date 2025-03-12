// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "../interfaces/vault/IVaultIndexActions.sol";
import "./RewardDrip.sol";

/**
 * @notice VaultIndexActions extends VaultBase and holds the logic to process index related data and actions.
 *
 * @dev
 * Index functions are executed when state changes are performed, to synchronize to vault with central Spool contract.
 * 
 * Index actions include:
 * - Redeem vault: claiming vault shares and withdrawn amount when DHW is complete
 * - Redeem user: claiming user deposit shares and/or withdrawn amount after vault claim has been processed
 * - Vault index: Incrementing vault index and mapping it to the global index
 */
abstract contract VaultIndexActions is IVaultIndexActions, RewardDrip {
    using SafeERC20 for IERC20;
    using Bitwise for uint256;

    /* ========== CONSTANTS ========== */

    /// @notice size of vault index in bits
    uint256 internal constant VAULT_INDEX_BIT_SIZE = 24;

    /* ========== STATE VARIABLES ========== */

    /// @notice Holds up to 2 vault indexes vault last interacted at and havend been claimed yet
    /// @dev Hecond index can only be the next index of the first one
    LastIndexInteracted public lastIndexInteracted;

    /// @notice Maps vault index to deposits and withdrawals for this index
    mapping(uint256 => IndexAction) public vaultIndexAction;
    
    /// @notice Maps user actions to the vault index
    mapping(address => mapping(uint256 => IndexAction)) public userIndexAction;

    /// @notice Holds up to 2 vault indexes users last interacted with, and havend been claimed yet
    mapping(address => LastIndexInteracted) public userLastInteractions;

    /// @notice Vault index to global index mapping
    mapping(uint256 => uint256) public vaultIndexToGlobalIndex;

    /// @notice Vault index to deposit and withdraw vault redeem 
    mapping(uint256 => Redeem) public redeems;

    /* ========== INITIALIZE ========== */

    /**
     * @notice Sets initial state of the vault.
     * @dev Called only once by vault factory after deploying a vault proxy.
     *      All values have been sanitized by the controller contract, meaning
     *      that no additional checks need to be applied here.
     */
    function initialize(
        VaultInitializable memory vaultInitializable
    ) external override initializer {
        _initializeBase(vaultInitializable);

        vaultIndex = 1;
    }

    // =========== VIEW FUNCTIONS ============ //

    function getGlobalIndexFromVaultIndex(uint256 _vaultIndex) public view returns(uint24 globalIndex) {
        (uint256 vaultIndexKey, uint256 vaultIndexPosition) = _getVaultIndexKeyAndPosition(_vaultIndex);
        uint256 indexes = vaultIndexToGlobalIndex[vaultIndexKey];
        globalIndex = indexes.get24BitUintByIndexCast(vaultIndexPosition);
    }

    function _isVaultRedistributingAtVaultIndex(uint256 _vaultIndex) internal view returns (bool isRedistributing) {
        if (_vaultIndex == redistibutionIndex) {
            isRedistributing = true;
        }
    }

    function _isVaultRedistributing() internal view returns (bool isRedistributing) {
        if (redistibutionIndex > 0) {
            isRedistributing = true;
        }
    }

    // =========== VAULT REDEEM ============ //

    /**
     * @notice Redeem vault strategies after do hard work (DHW) has been completed
     * 
     * @dev
     * This is only possible if all vault strategy DHWs have been executed, otherwise it's reverted.
     *
     * @param vaultStrategies strategies of this vault (verified internally)
     */
    function _redeemVaultStrategies(address[] memory vaultStrategies) internal {
        LastIndexInteracted memory _lastIndexInteracted = lastIndexInteracted;
        
        if (_lastIndexInteracted.index1 > 0) {
            uint256 globalIndex1 = getGlobalIndexFromVaultIndex(_lastIndexInteracted.index1);
            uint256 completedGlobalIndex = spool.getCompletedGlobalIndex();
            if (globalIndex1 <= completedGlobalIndex) {
                // redeem interacted index 1
                _redeemStrategiesIndex(_lastIndexInteracted.index1, globalIndex1, vaultStrategies);
                _lastIndexInteracted.index1 = 0;

                if (_lastIndexInteracted.index2 > 0) {
                    uint256 globalIndex2 = getGlobalIndexFromVaultIndex(_lastIndexInteracted.index2);
                    if (globalIndex2 <= completedGlobalIndex) {
                        // redeem interacted index 2
                        _redeemStrategiesIndex(_lastIndexInteracted.index2, globalIndex2, vaultStrategies);
                    } else {
                        _lastIndexInteracted.index1 = _lastIndexInteracted.index2;
                    }
                    
                    _lastIndexInteracted.index2 = 0;
                }

                lastIndexInteracted = _lastIndexInteracted;
            }
        }
    }

    // NOTE: causes additional gas for first interaction after DHW index has been completed
    function _redeemStrategiesIndex(uint256 _vaultIndex, uint256 globalIndex, address[] memory vaultStrategies) private {
        uint128 _totalShares = totalShares;
        uint128 totalReceived = 0;
        uint128 totalWithdrawn = 0;
        uint128 totalUnderlyingAtIndex = 0;
        
        // if vault was redistributing at index claim reallocation deposit
        bool isRedistributing = _isVaultRedistributingAtVaultIndex(_vaultIndex);
        if (isRedistributing) {
            spool.redeemReallocation(vaultStrategies, depositProportions, globalIndex);
            // Reset reallocation index to 0
            redistibutionIndex = 0;
        }

        // go over strategies and redeem deposited shares and withdrawn amount
        for (uint256 i = 0; i < vaultStrategies.length; i++) {
            address strat = vaultStrategies[i];
            (uint128 receivedTokens, uint128 withdrawnTokens) = spool.redeem(strat, globalIndex);
            totalReceived += receivedTokens;
            totalWithdrawn += withdrawnTokens;
            
            totalUnderlyingAtIndex += spool.getVaultTotalUnderlyingAtIndex(strat, globalIndex);
        }

        // redeem underlying withdrawn token for all strategies at once
        if (totalWithdrawn > 0) {
            spool.redeemUnderlying(totalWithdrawn);
        }

        // substract withdrawn shares
        _totalShares -= vaultIndexAction[_vaultIndex].withdrawShares;

        // calculate new deposit shares
        uint128 newShares = 0;
        if (_totalShares == 0 || totalUnderlyingAtIndex == 0) {
            newShares = totalReceived;
        } else {
            newShares = _getProportion128(totalReceived, _totalShares, totalUnderlyingAtIndex);
        }

        // add new deposit shares
        totalShares = _totalShares + newShares;

        redeems[_vaultIndex] = Redeem(newShares, totalWithdrawn);

        emit VaultRedeem(_vaultIndex);
    }

    // =========== USER REDEEM ============ //

    /**
     * @notice Redeem user deposit shares and withdrawn amount
     *
     * @dev
     * Check if vault has already claimed shares for itself
     */
    function _redeemUser() internal {
        LastIndexInteracted memory _lastIndexInteracted = lastIndexInteracted;
        LastIndexInteracted memory userIndexInteracted = userLastInteractions[msg.sender];

        // check if strategy for index has already been redeemed
        if (userIndexInteracted.index1 > 0 && 
            (_lastIndexInteracted.index1 == 0 || userIndexInteracted.index1 < _lastIndexInteracted.index1)) {
            // redeem interacted index 1
            _redeemUserAction(userIndexInteracted.index1, true);
            userIndexInteracted.index1 = 0;

            if (userIndexInteracted.index2 > 0) {
                if (_lastIndexInteracted.index2 == 0 || userIndexInteracted.index2 < _lastIndexInteracted.index1) {
                    // redeem interacted index 2
                    _redeemUserAction(userIndexInteracted.index2, false);
                } else {
                    userIndexInteracted.index1 = userIndexInteracted.index2;
                }
                
                userIndexInteracted.index2 = 0;
            }

            userLastInteractions[msg.sender] = userIndexInteracted;
        }
    }

    function _redeemUserAction(uint256 index, bool isFirstIndex) private {
        User storage user = users[msg.sender];
        IndexAction storage userIndex = userIndexAction[msg.sender][index];

        // redeem user withdrawn amount at index
        uint128 userWithdrawalShares = userIndex.withdrawShares;
        if (userWithdrawalShares > 0) {
            // calculate user withdrawn amount
            uint128 userWithdrawnAmount = _getProportion128(redeems[index].withdrawnAmount, userWithdrawalShares, vaultIndexAction[index].withdrawShares);

            user.owed += userWithdrawnAmount;

            // calculate proportionate deposit to pay for performance fees on claim
            uint128 proportionateDeposit;
            uint128 sharesAtWithdrawal = user.shares + userWithdrawalShares;
            if (isFirstIndex) {
                // if user has 2 withdraws pending sum shares from the pending one as well
                sharesAtWithdrawal += userIndexAction[msg.sender][index + 1].withdrawShares;
            }

            if (sharesAtWithdrawal > userWithdrawalShares) {
                uint128 userTotalDeposit = user.activeDeposit;
                
                proportionateDeposit = _getProportion128(userTotalDeposit, userWithdrawalShares, sharesAtWithdrawal);
                user.activeDeposit = userTotalDeposit - proportionateDeposit;
            } else {
                proportionateDeposit = user.activeDeposit;
                user.activeDeposit = 0;
            }

            user.withdrawnDeposits += proportionateDeposit;

            // set user withdraw shares for index to 0
            userIndex.withdrawShares = 0;
        }

        // redeem user deposit shares at index
        uint128 userDepositAmount = userIndex.depositAmount;
        if (userDepositAmount > 0) {
            // calculate new user deposit shares
            uint128 newUserShares = _getProportion128(userDepositAmount, redeems[index].depositShares, vaultIndexAction[index].depositAmount);

            user.shares += newUserShares;
            user.activeDeposit += userDepositAmount;

            // set user deposit amount for index to 0
            userIndex.depositAmount = 0;
        }
        
        emit UserRedeem(msg.sender, index);
    }

    // =========== VAULT INDEX ============ //

    /**
     * @dev Saves vault last interacted index
     */
    function _updateInteractedIndex() internal {
        _updateLastIndexInteracted(lastIndexInteracted);
    }

    /**
     * @dev Saves last user interacted index
     */
    function _updateUserInteractedIndex() internal {
        _updateLastIndexInteracted(userLastInteractions[msg.sender]);
    }

    function _updateLastIndexInteracted(LastIndexInteracted storage lit) private {
        if (lit.index1 > 0) {
            if (lit.index1 < vaultIndex) {
                lit.index2 = vaultIndex;
            }
        } else {
            lit.index1 = vaultIndex;
        }
    }

    /**
     * @dev Gets active global index and increments vault index if first interaction in the index
     */
    function _getAndSetActiveGlobalIndex() internal returns(uint256 activeGlobalIndex, uint24 _vaultIndex) {
        activeGlobalIndex = spool.getActiveGlobalIndex();
        _vaultIndex = _setActiveGlobalIndex(activeGlobalIndex);
    }

    function _setActiveGlobalIndex(uint256 activeGlobalIndex) internal returns(uint24 _vaultIndex) {
        _vaultIndex = vaultIndex;
        uint256 currentVaultGlobalIndex = getGlobalIndexFromVaultIndex(_vaultIndex);

        if (currentVaultGlobalIndex == 0) {
            _setGlobalIndex(activeGlobalIndex, _vaultIndex);
        } else if (currentVaultGlobalIndex != activeGlobalIndex) {
            _vaultIndex++;
            vaultIndex = _vaultIndex;
            _setGlobalIndex(activeGlobalIndex, _vaultIndex);
        }
    }

    function _getLazyVaultIndex() internal returns(uint24 _vaultIndex) {
        _vaultIndex = vaultIndex;
        uint256 activeGlobalIndex = spool.getActiveGlobalIndex();
        uint256 currentVaultGlobalIndex = getGlobalIndexFromVaultIndex(_vaultIndex);

        if (currentVaultGlobalIndex != 0 && currentVaultGlobalIndex != activeGlobalIndex) {
            _vaultIndex++;
            vaultIndex = _vaultIndex;
        }
    }

    function _setGlobalIndex(uint256 activeGlobalIndex, uint256 _vaultIndex) internal {
        (uint256 vaultIndexKey, uint256 vaultIndexPosition) = _getVaultIndexKeyAndPosition(_vaultIndex);
        uint256 indexes = vaultIndexToGlobalIndex[vaultIndexKey];
        vaultIndexToGlobalIndex[vaultIndexKey] = indexes.set24BitUintByIndex(vaultIndexPosition, activeGlobalIndex);
    }

    /**
     * @notice Calculates vault mapping index key and word position that map to global index.
     * @dev Mapping key is determined by dividing vault index by it's bit size.
     *      Word position is determined by applying modulo operator on vault index by bit size.
     */
    function _getVaultIndexKeyAndPosition(uint256 _vaultIndex) private pure returns(uint256, uint256) {
        uint256 vaultIndexKey = _vaultIndex / VAULT_INDEX_BIT_SIZE;

        uint256 vaultIndexPosition = _vaultIndex % VAULT_INDEX_BIT_SIZE;

        return (vaultIndexKey, vaultIndexPosition);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _noReallocation() private view {
        require(!_isVaultRedistributing(), "NRED");
    }

    /* ========== MODIFIERS ========== */

    modifier redeemVaultStrategiesModifier(address[] memory vaultStrategies) {
        _redeemVaultStrategies(vaultStrategies);
        _;
    }

    modifier redeemUserModifier() {
        _redeemUser();
        _;
    }

    modifier noReallocation() {
        _noReallocation();
        _;
    }  
}

