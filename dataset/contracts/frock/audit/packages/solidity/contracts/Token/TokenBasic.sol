// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../Extensions/ERC1363Upgradeable.sol";
import "../EIP/SafeTokenRecoverUpgradeable.sol";


contract TokenBasic is      
    Initializable, 
    UUPSUpgradeable,    
    ERC20CappedUpgradeable,
    ERC20BurnableUpgradeable,
    ERC20PermitUpgradeable,
    ERC1363Upgradeable,
    AccessControlUpgradeable,
    SafeTokenRecoverUpgradeable,
    PausableUpgradeable,
    ERC20SnapshotUpgradeable
{            
    bytes32 public constant SNAPSHOTER = keccak256("SNAPSHOTER");

    mapping (address => bool) public isExcludedFromFees;    
    mapping(address => bool) public isBlacklisted;

    event ExcludeFromFees(address indexed account, bool isExcluded);   
    event Blacklisted(address indexed account, bool blacklisted);

    function initialize(
        string memory name,
        string memory symbol,
        uint256 cap        
    ) public initializer {
        __Context_init_unchained();        
        
        __ERC20_init_unchained(name, symbol);
        __EIP712_init_unchained(name, "1");
        __ERC20Permit_init_unchained(name);        
        __ERC165_init_unchained();
        __AccessControl_init_unchained();        

    
        __ERC20Capped_init_unchained(cap);
        __ERC20Burnable_init_unchained();     
        __ERC20Snapshot_init_unchained();           
        __ERC1363_init_unchained();        
        __SafeTokenRecover_init_unchained();        
        __Pausable_init_unchained();

        // Setup deployer as Admin when construction
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        // Minting
        _mint(_msgSender(), cap);
                     		
        // Exclude From Fee
        isExcludedFromFees[msg.sender] = true;

    }
		
    function excludeFromFees(address account, bool excluded) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(isExcludedFromFees[account] != excluded, "Account is already the value of 'excluded'");
        isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function setBlacklist(address account, bool blacklisted) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(isBlacklisted[account] != blacklisted, "Account is already the value of 'blacklisted'");
        isBlacklisted[account] = blacklisted;
        emit Blacklisted(account, blacklisted);
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 9;
    }

    /**
     * Function that should revert when msg.sender is not authorized to upgrade
     * the contract.
     *
     * Called by upgradeTo and upgradeToAndCall.
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override        
    {
        require(_msgSender() == _getAdmin(), "Not the Owner of Contract");
    } // solhint-disable-line no-empty-blocks

     /**
     * @dev Function to mint tokens.
     *
     * @param account The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function _mint(address account, uint256 amount)
        internal
        virtual
        override(ERC20CappedUpgradeable, ERC20Upgradeable)
    {
        ERC20CappedUpgradeable._mint(account, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20SnapshotUpgradeable, ERC20Upgradeable) {
        require(!PausableUpgradeable.paused(), "ERC20Pausable: token transfer while paused");
        require(!isBlacklisted[from] && !isBlacklisted[to], "Blacklisted: user blacklisted");
        ERC20SnapshotUpgradeable._beforeTokenTransfer(from, to, amount);                
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        PausableUpgradeable._pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        PausableUpgradeable._unpause();
    }

    function paused() public view override virtual returns (bool) {
        return PausableUpgradeable.paused();
    }



     /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1363Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {        
        return
            ERC1363Upgradeable.supportsInterface(interfaceId) ||
            AccessControlUpgradeable.supportsInterface(interfaceId);
    }

    function snapshot() external onlyRole(SNAPSHOTER) returns (uint256) {
        return super._snapshot();
    }

    function lastSnapshotId() external view returns (uint256) {
        return super._getCurrentSnapshotId();
    }
}