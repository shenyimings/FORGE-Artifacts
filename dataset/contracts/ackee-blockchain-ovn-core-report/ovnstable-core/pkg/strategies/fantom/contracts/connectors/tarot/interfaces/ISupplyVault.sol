// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IBorrowable.sol";
import "./ISupplyVaultStrategy.sol";

interface ISupplyVault {
    /* Vault */
    function enter(uint256 _amount) external returns (uint256 share);

    function enterWithToken(address _tokenAddress, uint256 _tokenAmount) external returns (uint256 share);

    function leave(uint256 _share) external returns (uint256 underlyingAmount);

    function leaveInKind(uint256 _share) external;

    function applyFee() external;

    /** Read */

    function getBorrowablesLength() external view returns (uint256);

    function getBorrowableEnabled(IBorrowable borrowable) external view returns (bool);

    function getBorrowableExists(IBorrowable borrowable) external view returns (bool);

    function indexOfBorrowable(IBorrowable borrowable) external view returns (uint256);

    function borrowables(uint256) external view returns (IBorrowable);

    function underlying() external view returns (IERC20);

    function strategy() external view returns (ISupplyVaultStrategy);

    function pendingStrategy() external view returns (ISupplyVaultStrategy);

    function pendingStrategyNotBefore() external view returns (uint256);

    function feeBps() external view returns (uint256);

    function feeTo() external view returns (address);

    function reallocateManager() external view returns (address);

    /* Read functions that are non-view due to updating exchange rates */
    function underlyingBalanceForAccount(address _account) external returns (uint256 underlyingBalance);

    function shareValuedAsUnderlying(uint256 _share) external returns (uint256 underlyingAmount_);

    function underlyingValuedAsShare(uint256 _underlyingAmount) external returns (uint256 share_);

    function getTotalUnderlying() external returns (uint256 totalUnderlying);

    function getSupplyRate() external returns (uint256 supplyRate_);

    /* Only from strategy */

    function allocateIntoBorrowable(IBorrowable borrowable, uint256 underlyingAmount) external;

    function deallocateFromBorrowable(IBorrowable borrowable, uint256 borrowableAmount) external;

    function reallocate(uint256 _share, bytes calldata _data) external;

    /* Only owner */
    function addBorrowable(address _address) external;

    function addBorrowables(address[] calldata _addressList) external;

    function removeBorrowable(IBorrowable borrowable) external;

    function disableBorrowable(IBorrowable borrowable) external;

    function enableBorrowable(IBorrowable borrowable) external;

    function unwindBorrowable(IBorrowable borrowable, uint256 borowableAmount) external;

    function updatePendingStrategy(ISupplyVaultStrategy _newPendingStrategy, uint256 _notBefore) external;

    function updateStrategy() external;

    function updateFeeBps(uint256 _newFeeBps) external;

    function updateFeeTo(address _newFeeTo) external;

    function updateReallocateManager(address _newReallocateManager) external;

    function pause() external;

    function unpause() external;

    /* Voting */
    function delegates(address delegator) external view returns (address);

    function delegate(address delegatee) external;

    function delegateBySig(
        address delegatee,
        uint nonce,
        uint expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function getCurrentVotes(address account) external view returns (uint256);

    function getPriorVotes(address account, uint blockNumber) external view returns (uint256);

    /* Events */
    event AddBorrowable(address indexed borrowable);
    event RemoveBorrowable(address indexed borrowable);
    event EnableBorrowable(address indexed borrowable);
    event DisableBorrowable(address indexed borrowable);
    event UpdatePendingStrategy(address indexed strategy, uint256 notBefore);
    event UpdateStrategy(address indexed strategy);
    event UpdateFeeBps(uint256 newFeeBps);
    event UpdateFeeTo(address indexed newFeeTo);
    event UpdateReallocateManager(address indexed newReallocateManager);
    event UnwindBorrowable(address indexed borrowable, uint256 underlyingAmount, uint256 borrowableAmount);
    event Enter(
        address indexed who,
        address indexed token,
        uint256 tokenAmount,
        uint256 underlyingAmount,
        uint256 share
    );
    event Leave(address indexed who, uint256 share, uint256 underlyingAmount);
    event LeaveInKind(address indexed who, uint256 share);
    event Reallocate(address indexed sender, uint256 share);
    event AllocateBorrowable(address indexed borrowable, uint256 underlyingAmount, uint256 borrowableAmount);
    event DeallocateBorrowable(address indexed borrowable, uint256 borrowableAmount, uint256 underlyingAmount);

    event ApplyFee(address indexed feeTo, uint256 gain, uint256 fee, uint256 feeShare);
    event UpdateCheckpoint(uint256 checkpointBalance);
}