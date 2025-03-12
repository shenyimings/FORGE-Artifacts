pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/** @title VePika
    @notice The contract is used for both Pika and esPika. Pika is a transferable token,
    and esPika is a non-transferable token which can be linearly vested to PIKA token via vesting contract.
 */
contract Pika is AccessControl, ERC20, ERC20Burnable {
    /// @dev The identifier of the role which maintains other roles.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    /// @dev The identifier of the role which allows accounts to mint tokens.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER");
    /// @dev The identifier of the role which allows special transfer privileges.
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER");

    /// @dev bool flag of whether transfer is currently allowed for all people.
    bool public transfersAllowed = false;

    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        address beneficiary,
        address gov
    ) ERC20(name, symbol) {
        // We are minting initialSupply number of tokens
        _mint(beneficiary, totalSupply);
        // Add beneficiary as minter
        _setupRole(MINTER_ROLE, beneficiary);
        // Add beneficiary as transferer
        _setupRole(TRANSFER_ROLE, beneficiary);
        // Add beneficiary as admin
        _setupRole(ADMIN_ROLE, beneficiary);
        // Set ADMIN role as admin of transfer role
        _setRoleAdmin(TRANSFER_ROLE, ADMIN_ROLE);
        // Set default admin role: it will be able to grant and revoke any roles
        _setupRole(DEFAULT_ADMIN_ROLE, gov);
    }

    /// @dev A modifier which checks that the caller has the minter role.
    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "PIKA: only minter");
        _;
    }

    /// @dev A modifier which checks that the caller has the admin role.
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "PIKA: only admin");
        _;
    }

    /// @dev A modifier which checks that the caller has transfer privileges.
    modifier onlyTransferer(address from) {
        require(
            transfersAllowed ||
            from == address(0) ||
            hasRole(TRANSFER_ROLE, msg.sender),
            "PIKA: no transfer privileges"
        );
        _;
    }

    /// @dev Mints tokens to a recipient.
    ///
    /// This function reverts if the caller does not have the minter role.
    function mint(address _recipient, uint256 _amount) external onlyMinter {
        _mint(_recipient, _amount);
    }

    /// @dev Toggles transfer allowed flag.
    ///
    /// This function reverts if the caller does not have the admin role.
    function setTransfersAllowed(bool _transfersAllowed) external onlyAdmin {
        transfersAllowed = _transfersAllowed;
        emit TransfersAllowed(transfersAllowed);
    }

    /// @dev Hook that is called before any transfer of tokens.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override onlyTransferer(from) {}

    /// @dev Emitted when transfer toggle is switched
    event TransfersAllowed(bool transfersAllowed);
}