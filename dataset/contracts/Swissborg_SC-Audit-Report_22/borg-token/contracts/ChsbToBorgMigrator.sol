// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/// @title ChsbToBorgMigrator
/// @notice This contract implements the migration from the CHSB to the BORG token.
/// @author SwissBorg
contract ChsbToBorgMigrator is OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice The contract address of $CHSB.
    IERC20Upgradeable public CHSB;
    /// @notice The contract address of $BORG.
    IERC20Upgradeable public BORG;

    /// @notice The total number of $CHSB migrated to $BORG.
    uint256 public totalChsbMigrated;

    /// @notice The manager can pause the contract.
    address public manager;

    /// @notice The event is emitted when a migration is completed.
    /// @param sender The caller of the migration.
    /// @param amount The amount migrated.
    event ChsbMigrated(address indexed sender, uint256 indexed amount);

    /// @notice The event is emitted when a new manager is set.
    /// @param newManager The address of the new manager.
    event SetManager(address indexed newManager);

    /// @notice Requires that the function is called by the manager.
    modifier onlyManager {
        require(msg.sender == manager, "ONLY_MANAGER");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// Creates a ChsbToBorgMigrator.
    /// @param _chsb The contract address of the $CHSB token.
    /// @param _borg The contract address of the $BORG token.
    /// @param owner_ The address of the owner of the contract.
    /// @param _manager The address of the owner of the contract.
    function initialize(address _chsb, address _borg, address owner_, address _manager) public initializer {
        require(_chsb != address(0), "ADDRESS_ZERO");
        require(_borg != address(0), "ADDRESS_ZERO");
        require(owner_ != address(0), "ADDRESS_ZERO");
        require(_manager != address(0), "ADDRESS_ZERO");

        __Ownable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        CHSB = IERC20Upgradeable(_chsb);
        BORG = IERC20Upgradeable(_borg);
        manager = _manager;

        // Transfer the ownership at start.
        _transferOwnership(owner_);
        // Pause the contract at start.
        _pause();
    }

    /// @notice Migrates the $CHSB to $BORG.
    /// @param _amount The amount of $CHSB to migrate.
    function migrate(uint256 _amount) external whenNotPaused {
        require(IERC20Upgradeable(CHSB).totalSupply() == 1_000_000_000 * 10 ** 8, "CHSB_SUPPLY_WRONG");
        require(_amount > 0, "AMOUNT_ZERO");

        // $CHSB has 8 decimals while $BORG has 18 decimals. We need to add 10 ** 10 to the amount of $BORG sent.
        uint256 decimalsScale = 10 ** 10;

        // Migrate
        totalChsbMigrated = totalChsbMigrated + _amount;
        CHSB.safeTransferFrom(msg.sender, address(this), _amount);
        BORG.safeTransfer(msg.sender, _amount * decimalsScale);

        emit ChsbMigrated(msg.sender, _amount);
    }

    /// @notice Pauses the migration.
    function pause() external onlyManager {
        _pause();
    }

    /// @notice Returns the contract to a normal state.
    function unpause() external onlyManager {
        _unpause();
    }

    /// @notice Sets a new manager.
    /// @param _manager The address of the new manager.
    function setManager(address _manager) external onlyOwner {
        require(_manager != address(0), "ADDRESS_ZERO");
        manager = _manager;
        emit SetManager(_manager);
    }

    /// @notice Returns the current implementation address.
    /// @return The address of the implementation.
    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}