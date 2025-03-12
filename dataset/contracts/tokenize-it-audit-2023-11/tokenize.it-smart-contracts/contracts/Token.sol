// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./AllowList.sol";
import "./interfaces/IFeeSettings.sol";

/**
 * @title tokenize.it Token
 * @author malteish, cjentzsch
 * @notice This contract implements the token used to tokenize companies, which follows the ERC20 standard and adds the following features:
 *     - pausing
 *     - access control with dedicated roles
 *     - burning (burner role can burn any token from any address)
 *     - requirements for sending and receiving tokens
 *     - allow list (documents which address satisfies which requirement)
 *     Decimals is inherited as 18 from ERC20. This should be the standard to adhere by for all deployments of this token.
 *
 * @dev The contract inherits from ERC2771Context in order to be usable with Gas Station Network (GSN) https://docs.opengsn.org/faq/troubleshooting.html#my-contract-is-using-openzeppelin-how-do-i-add-gsn-support and meta-transactions.
 */
contract Token is
    ERC2771ContextUpgradeable,
    ERC20PermitUpgradeable,
    ERC20SnapshotUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    /// @notice The role that has the ability to define which requirements an address must satisfy to receive tokens
    bytes32 public constant REQUIREMENT_ROLE = keccak256("REQUIREMENT_ROLE");
    /// @notice The role that has the ability to grant minting allowances
    bytes32 public constant MINTALLOWER_ROLE = keccak256("MINTALLOWER_ROLE");
    /// @notice The role that has the ability to burn tokens from anywhere. Usage is planned for legal purposes and error recovery.
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    /// @notice The role that has the ability to grant transfer rights to other addresses
    bytes32 public constant TRANSFERERADMIN_ROLE = keccak256("TRANSFERERADMIN_ROLE");
    /// @notice Addresses with this role do not need to satisfy any requirements to send or receive tokens
    bytes32 public constant TRANSFERER_ROLE = keccak256("TRANSFERER_ROLE");
    /// @notice The role that has the ability to pause the token. Transferring, burning and minting will not be possible while the contract is paused.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    /// @notice The role that can create snapshots of the token balances
    bytes32 public constant SNAPSHOTCREATOR_ROLE = keccak256("SNAPSHOTCREATOR_ROLE");

    /**
     * @dev This empty reserved space is put in place to allow future versions to inherit
     * from contracts that need storage. This mimics openzeppelin's approach.
     * For more information, see https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     * Its size is chosen for the first used variable (allowList) to be in storage slot 1000.
     * This is checked in the testTokenStorageGap unit test.
     * Whenever an inheritance is added, removed or changed, the storage location of allowList and
     * all following variables is likely to change too, with catastrophic results. So remember to update
     * this gap in order to keep allowList at position 1000!
     * More info at [../docs/upgradeability.md]
     */
    uint256[446] private __gap;

    // Map managed by tokenize.it, which assigns addresses requirements which they fulfill
    AllowList public allowList;

    // Fee settings of tokenize.it
    IFeeSettingsV2 public feeSettings;

    // Suggested new fee settings, which will be applied after admin approval
    IFeeSettingsV2 public suggestedFeeSettings;
    /**
     * @notice  defines requirements to send or receive tokens for non-TRANSFERER_ROLE. If zero, everbody can transfer the token. If non-zero, then only those who have met the requirements can send or receive tokens.
     *     Requirements can be defined by the REQUIREMENT_ROLE, and are validated against the allowList. They can include things like "must have a verified email address", "must have a verified phone number", "must have a verified identity", etc.
     *     Also, tiers from 0 to four can be used.
     * @dev Requirements are defined as bit mask, with the bit position encoding it's meaning and the bit's value whether this requirement will be enforced.
     *     Example:
     *     - position 0: 1 = must be KYCed (0 = no KYC required)
     *     - position 1: 1 = must be american citizen (0 = american citizenship not required)
     *     - position 2: 1 = must be a penguin (0 = penguin status not required)
     *     These meanings are not defined within code, neither in the token contract nor the allowList. Nevertheless, the definition used by the people responsible for both contracts MUST match,
     *     or the token contract will not work as expected. E.g. if the allowList defines position 2 as "is a penguin", while the token contract uses position 2 as "is a hedgehog", then the tokens
     *     might be sold to hedgehogs, which was never the intention.
     *     Here some examples of how requirements can be used in practice:
     *     With requirements 0b0000000000000000000000000000000000000000000000000000000000000101, only KYCed penguins will be allowed to send or receive tokens.
     *     With requirements 0b0000000000000000000000000000000000000000000000000000000000000111, only KYCed american penguins will be allowed to send or receive tokens.
     *     With requirements 0b0000000000000000000000000000000000000000000000000000000000000000, even french hedgehogs will be allowed to send or receive tokens.
     *
     *     The highest four bits are defined as tiers as follows:
     *     - 0b0000000000000000000000000000000000000000000000000000000000000000 = tier 0 is required
     *     - 0b0001000000000000000000000000000000000000000000000000000000000000 = tier 1 is required
     *     - 0b0010000000000000000000000000000000000000000000000000000000000000 = tier 2 is required
     *     - 0b0100000000000000000000000000000000000000000000000000000000000000 = tier 3 is required
     *     - 0b1000000000000000000000000000000000000000000000000000000000000000 = tier 4 is required
     *
     *     Keep in mind that addresses with the TRANSFERER_ROLE do not need to satisfy any requirements to send or receive tokens.
     */
    uint256 public requirements;

    /**
     * @notice defines the maximum amount of tokens that can be minted by a specific address. If zero, no tokens can be minted.
     *      Tokens paid as fees, as specified in the `feeSettings` contract, do not require an allowance.
     *      Example: Fee is set to 1% and mintingAllowance is 100. When executing the `mint` function with 100 as `amount`,
     *      100 tokens will be minted to the `to` address, and 1 token to the feeCollector.
     */
    mapping(address => uint256) public mintingAllowance; // used for token generating events such as vesting or new financing rounds

    /**
     * @notice The version of the token contract. This is used to keep track of upgrades.
     * @dev The token contract is upgradeable, so the version is stored in the contract itself. Updating the logic contract address
     *  in the proxy will not change the version. If desired, the version must be changed in the new initializer function.
     */
    uint256 public version;

    /// @param newRequirements The new requirements that will be enforced from now on.
    event RequirementsChanged(uint newRequirements);
    /// @param newAllowList The AllowList contract that is in use from now on.
    event AllowListChanged(AllowList indexed newAllowList);
    /// @param suggestedFeeSettings The FeeSettings contract that has been suggested, but not yet approved by the admin.
    event NewFeeSettingsSuggested(IFeeSettingsV2 indexed suggestedFeeSettings);
    /// @param newFeeSettings The FeeSettings contract that is in use from now on.
    event FeeSettingsChanged(IFeeSettingsV2 indexed newFeeSettings);
    /// @param minter The address for which the minting allowance has been changed.
    /// @param newAllowance The new minting allowance for the address (does not include fees).
    event MintingAllowanceChanged(address indexed minter, uint256 newAllowance);

    /**
     * @notice Constructor a token logic contract that can be used by clones. It does not initialize state variables properly, so the resulting contract will not be functional.
     * @param _trustedForwarder trusted forwarder for the ERC2771Context constructor - used for meta-transactions. OpenGSN v2 Forwarder should be used.
     */
    constructor(address _trustedForwarder) ERC2771ContextUpgradeable(_trustedForwarder) {
        _disableInitializers();
    }

    /**
     * @notice Initializer for the token, replaces the constructor
     * @param _feeSettings fee settings contract that determines the fee for minting tokens
     * @param _admin address of the admin. Admin will initially have all roles and can grant roles to other addresses.
     * @param _name name of the specific token, e.g. "MyGmbH Token"
     * @param _symbol symbol of the token, e.g. "MGT"
     * @param _allowList allowList contract that defines which addresses satisfy which requirements
     * @param _requirements requirements an address has to meet for sending or receiving tokens
     */
    function initialize(
        IFeeSettingsV2 _feeSettings,
        address _admin,
        AllowList _allowList,
        uint256 _requirements,
        string memory _name,
        string memory _symbol
    ) public initializer {
        // Grant admin roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin); // except for the Transferer role, the _admin is the roles admin for all other roles
        _setRoleAdmin(TRANSFERER_ROLE, TRANSFERERADMIN_ROLE);

        // grant all roles to admin for now. Can be changed later, see https://docs.openzeppelin.com/contracts/4.x/api/access#IAccessControl
        _grantRole(REQUIREMENT_ROLE, _admin);
        _grantRole(MINTALLOWER_ROLE, _admin);
        _grantRole(BURNER_ROLE, _admin);
        _grantRole(TRANSFERERADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(SNAPSHOTCREATOR_ROLE, _admin);

        // set up fee collection
        _checkIfFeeSettingsImplementsInterface(_feeSettings);
        feeSettings = _feeSettings;

        // set up allowList
        require(address(_allowList) != address(0), "AllowList must not be zero address");
        allowList = _allowList;

        // set requirements (can be 0 to allow everyone to send and receive tokens)
        requirements = _requirements;

        // set version (can be updated in proxy storage by later implementation contracts)
        version = 1;

        __ERC20Permit_init(_name);
        __ERC20Snapshot_init();
        __ERC20_init(_name, _symbol);
        __UUPSUpgradeable_init();
    }

    /**
     * This function is called during the upgrade process. The modifier onlyRole(DEFAULT_ADMIN_ROLE)
     * is used to make sure that only the admin can perform upgrades.
     * @dev REMEMBER to make the new logic contract ERC1967Upgrade compatible, and, if required,
     * include a new initializer function!
     * @param newImplementation address of the new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * @notice Change the AllowList that defines which addresses satisfy which requirements to `_allowList`.
     * @dev An interface check is not necessary because AllowList can not break the token like FeeSettings could.
     * @param _allowList new AllowList contract
     */
    function setAllowList(AllowList _allowList) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(_allowList) != address(0), "AllowList must not be zero address");
        allowList = _allowList;
        emit AllowListChanged(_allowList);
    }

    /**
     * @notice Change the requirements an address has to meet for sending or receiving tokens to `_requirements`.
     * @param _requirements requirements an address has to meet for sending or receiving tokens
     */
    function setRequirements(uint256 _requirements) external onlyRole(REQUIREMENT_ROLE) {
        requirements = _requirements;
        emit RequirementsChanged(_requirements);
    }

    /**
     * @notice This function can only be used by the feeSettings owner to suggest switching to a new feeSettings contract.
     *      The new feeSettings contract will be applied immediately after admin approval.
     * @dev This is a possibility to change fees without honoring the delay enforced in the feeSettings contract. Therefore, approval of the admin is required.
     *     The feeSettings contract can brick the token, so an interface check is necessary.
     * @param _feeSettings the new feeSettings contract
     */
    function suggestNewFeeSettings(IFeeSettingsV2 _feeSettings) external {
        require(_msgSender() == feeSettings.owner(), "Only fee settings owner can suggest fee settings update");
        _checkIfFeeSettingsImplementsInterface(_feeSettings);
        suggestedFeeSettings = _feeSettings;
        emit NewFeeSettingsSuggested(_feeSettings);
    }

    /**
     * @notice This function can only be used by the default admin to approve switching to the new feeSettings contract.
     *     The new feeSettings contract will be applied immediately.
     * @dev Enforcing the suggested and accepted new contract to be the same is necessary to prevent frontrunning the acceptance with a new suggestion.
     *      Checking if the address implements the interface also prevents the 0 address from being accepted.
     * @param _feeSettings the new feeSettings contract
     */
    function acceptNewFeeSettings(IFeeSettingsV2 _feeSettings) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // after deployment, suggestedFeeSettings is 0x0. Therefore, this check is necessary, otherwise the admin could accept 0x0 as new feeSettings.
        // Checking that the suggestedFeeSettings is not 0x0 would work, too, but this check is used in other places, too.
        _checkIfFeeSettingsImplementsInterface(_feeSettings);

        require(_feeSettings == suggestedFeeSettings, "Only suggested fee settings can be accepted");
        feeSettings = suggestedFeeSettings;
        emit FeeSettingsChanged(_feeSettings);
    }

    /**
     * @notice Increase the amount of tokens `_minter` can mint by `_allowance`. Any address can be used, e.g. of an investment contract like PrivateOffer, a vesting contract, or an EOA.
     *      The contract does not keep track of how many tokens a minter has minted over time
     * @param _minter address of the minter
     * @param _allowance how many tokens can be minted by this minter, in addition to their current allowance (excluding the tokens minted as a fee)
     */
    function increaseMintingAllowance(address _minter, uint256 _allowance) external onlyRole(MINTALLOWER_ROLE) {
        mintingAllowance[_minter] += _allowance;
        emit MintingAllowanceChanged(_minter, mintingAllowance[_minter]);
    }

    /**
     * @notice Reduce the amount of tokens `_minter` can mint by `_allowance`.
     * @dev Underflow is cast to 0 in order to be able to use decreaseMintingAllowance(minter, UINT256_MAX) to reset the allowance to 0.
     * @param _minter address of the minter
     * @param _allowance how many tokens should be deducted from the current minting allowance (excluding the tokens minted as a fee)
     */
    function decreaseMintingAllowance(address _minter, uint256 _allowance) external onlyRole(MINTALLOWER_ROLE) {
        if (mintingAllowance[_minter] > _allowance) {
            mintingAllowance[_minter] -= _allowance;
            emit MintingAllowanceChanged(_minter, mintingAllowance[_minter]);
        } else {
            mintingAllowance[_minter] = 0;
            emit MintingAllowanceChanged(_minter, 0);
        }
    }

    /**
     * @notice Mint `_amount` tokens to `_to` and pay the fee to the fee collector
     * @param _to address that receives the tokens
     * @param _amount how many tokens to mint
     */
    function mint(address _to, uint256 _amount) external {
        if (!hasRole(MINTALLOWER_ROLE, _msgSender())) {
            require(mintingAllowance[_msgSender()] >= _amount, "MintingAllowance too low");
            mintingAllowance[_msgSender()] -= _amount;
        }
        // this check is executed here, because later minting of the buy amount can not be differentiated from minting of the fee amount
        _checkIfAllowedToTransact(_to);
        _mint(_to, _amount);
        // collect fees
        uint256 fee = feeSettings.tokenFee(_amount, address(this));
        if (fee != 0) {
            // the fee collector is always allowed to receive tokens
            _mint(feeSettings.tokenFeeCollector(address(this)), fee);
        }
    }

    /**
     * @notice Burn `_amount` tokens from `_from`.
     * @param _from address that holds the tokens
     * @param _amount how many tokens to burn
     */
    function burn(address _from, uint256 _amount) external onlyRole(BURNER_ROLE) {
        _burn(_from, _amount);
    }

    /**
     * This token can keep track of historical balances. In order to store all current balances, a snapshot must be created.
     * Call this function to create a snapshot. The historical balances can be accessed with the balanceOfAt function.
     * They could be used to determine eligibility for airdrops or dividends.
     * @return id of the snapshot
     */
    function createSnapshot() external onlyRole(SNAPSHOTCREATOR_ROLE) returns (uint256) {
        return _snapshot();
    }

    /**
     * @notice There are 3 types of transfers:
     *    1. minting: transfers from the zero address to another address. Only minters can do this, which is checked in the mint function. The recipient must be allowed to transact.
     *    2. burning: transfers from an address to the zero address. Only burners can do this, which is checked in the burn function.
     *    3. transfers from one address to another. The sender and recipient must be allowed to transact.
     * @dev this hook is executed before the transfer function itself
     */
    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual override(ERC20SnapshotUpgradeable, ERC20Upgradeable) {
        super._beforeTokenTransfer(_from, _to, _amount);
        _requireNotPaused();
        if (_from != address(0) && _to != address(0)) {
            // token transfer
            _checkIfAllowedToTransact(_from);
            _checkIfAllowedToTransact(_to);
        }
        /*  if _from is 0x0, tokens are minted:
                - receiver's properties are checked in the mint function
                - the minter's allowance is checked in the mint function
                - extra tokens can be minted for feeCollector in the mint function
            if _to is 0x0, tokens are burned: 
                - only burner is allowed to do this, which is checked in the burn function
        */
    }

    /**
     * @notice checks if `_address` is either a transferer or satisfies the requirements.
     * @param _address address to check
     */
    function _checkIfAllowedToTransact(address _address) internal view {
        require(
            requirements == 0 ||
                hasRole(TRANSFERER_ROLE, _address) ||
                allowList.map(_address) & requirements == requirements,
            "Sender or Receiver is not allowed to transact. Either locally issue the role as a TRANSFERER or they must meet requirements as defined in the allowList"
        );
    }

    /**
     * @notice Make sure `_feeSettings` actually implements the interfaces that are needed.
     *          This is a sanity check to make sure that the FeeSettings contract is actually compatible with this token.
     * @dev  This check uses EIP165, see https://eips.ethereum.org/EIPS/eip-165
     * @param _feeSettings address of the FeeSettings contract
     */
    function _checkIfFeeSettingsImplementsInterface(IFeeSettingsV2 _feeSettings) internal view {
        // step 1: needs to return true if EIP165 is supported
        require(_feeSettings.supportsInterface(0x01ffc9a7) == true, "FeeSettings must implement IFeeSettingsV2");
        // step 2: needs to return false if EIP165 is supported
        require(_feeSettings.supportsInterface(0xffffffff) == false, "FeeSettings must implement IFeeSettingsV2");
        // now we know EIP165 is supported
        // step 3: needs to return true if IFeeSettingsV2 is supported
        require(
            _feeSettings.supportsInterface(type(IFeeSettingsV2).interfaceId),
            "FeeSettings must implement IFeeSettingsV2"
        );
    }

    /**
     * pause the token contract. No transfers, burning or minting will be possible while the contract is paused.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * unpause the token contract. Transfers, burning and minting will be possible again.
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev both ERC20Pausable and ERC2771Context have a _msgSender() function, so we need to override and select which one to use.
     */
    function _msgSender() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (address) {
        return ERC2771ContextUpgradeable._msgSender();
    }

    /**
     * @dev both ERC20Pausable and ERC2771Context have a _msgData() function, so we need to override and select which one to use.
     */
    function _msgData() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (bytes calldata) {
        return ERC2771ContextUpgradeable._msgData();
    }
}
