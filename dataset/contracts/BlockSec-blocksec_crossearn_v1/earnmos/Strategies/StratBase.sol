// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../Interfaces/IStrategy.sol";

abstract contract StratBase is IStrategy, OwnableUpgradeable {
    address public override vault;
    IERC20 public override want;
    address public keeper;
    address public feeRecipient;

    event VaultUpdated(address _vault);
    event WantUpdated(address _want);
    event KeeperUpdated(address _keeper);
    event FeeRecipientUpdated(address _feeRecipient);

    function __StratBase_init() internal initializer {
        __Ownable_init();

        __StratBase_init_unchained();
    }

    function __StratBase_init_unchained() internal initializer {}

    /**
     * @dev Initializes the base strategy.
     * @param _vault address of parent vault.
     * @param _want address of want.
     * @param _keeper address to use as alternative owner.
     * @param _feeRecipient address where to send Beefy's fees.
     */
    function setAddresses(
        address _vault,
        address _want,
        address _keeper,
        address _feeRecipient
    ) internal onlyOwner {
        vault = _vault;
        want = IERC20(_want);
        keeper = _keeper;
        feeRecipient = _feeRecipient;

        emit VaultUpdated(_vault);
        emit WantUpdated(_want);
        emit KeeperUpdated(_keeper);
        emit FeeRecipientUpdated(_feeRecipient);
    }

    // checks that caller is either owner or keeper.
    modifier onlyManager() {
        require(msg.sender == owner() || msg.sender == keeper, "!manager");
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyVault() {
        require(msg.sender == vault, "caller is not the vault");
        _;
    }

    /**
     * @dev Updates parent vault.
     * @param _vault new vault address.
     */
    function setVault(address _vault) external onlyOwner {
        vault = _vault;

        emit VaultUpdated(_vault);
    }

    /**
     * @dev Updates address of the strat keeper.
     * @param _keeper new keeper address.
     */
    function setKeeper(address _keeper) external onlyManager {
        keeper = _keeper;

        emit KeeperUpdated(_keeper);
    }

    /**
     * @dev Updates fee recipient.
     * @param _feeRecipient new beefy fee recipient address.
     */
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        feeRecipient = _feeRecipient;

        emit FeeRecipientUpdated(_feeRecipient);
    }
}
