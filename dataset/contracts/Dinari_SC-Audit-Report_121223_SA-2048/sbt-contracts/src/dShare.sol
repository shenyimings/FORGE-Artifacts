// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import {ERC20} from "solady/src/tokens/ERC20.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {IdShare, ITransferRestrictor} from "./IdShare.sol";

/// @notice Core token contract for bridged assets.
/// @author Dinari (https://github.com/dinaricrypto/sbt-contracts/blob/main/src/dShare.sol)
/// ERC20 with minter, burner, and blacklist
/// Uses solady ERC20 which allows EIP-2612 domain separator with `name` changes
contract dShare is IdShare, Initializable, ERC20, AccessControlDefaultAdminRulesUpgradeable {
    /// ------------------ Types ------------------ ///

    error Unauthorized();

    /// @dev Emitted when `name` is set
    event NameSet(string name);
    /// @dev Emitted when `symbol` is set
    event SymbolSet(string symbol);
    /// @dev Emitted when `disclosures` URI is set
    event DisclosuresSet(string disclosures);
    /// @dev Emitted when transfer restrictor contract is set
    event TransferRestrictorSet(ITransferRestrictor indexed transferRestrictor);

    /// ------------------ Immutables ------------------ ///

    /// @notice Role for approved minters
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /// @notice Role for approved burners
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// ------------------ State ------------------ ///

    struct dShareStorage {
        string _name;
        string _symbol;
        ITransferRestrictor _transferRestrictor;
    }

    // keccak256(abi.encode(uint256(keccak256("dinaricrypto.storage.dShare")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant dShareStorageLocation = 0x7315beb2381679795e06870021c0fca5deb85616e29e098c2e7b7e488f185800;

    function _getdShareStorage() private pure returns (dShareStorage storage $) {
        assembly {
            $.slot := dShareStorageLocation
        }
    }

    /// ------------------ Initialization ------------------ ///

    function initialize(
        address owner,
        string memory _name,
        string memory _symbol,
        ITransferRestrictor _transferRestrictor
    ) public initializer {
        __AccessControlDefaultAdminRules_init_unchained(0, owner);

        dShareStorage storage $ = _getdShareStorage();
        $._name = _name;
        $._symbol = _symbol;
        $._transferRestrictor = _transferRestrictor;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// ------------------ Getters ------------------ ///

    /// @notice Token name
    function name() public view override returns (string memory) {
        dShareStorage storage $ = _getdShareStorage();
        return $._name;
    }

    /// @notice Token symbol
    function symbol() public view override returns (string memory) {
        dShareStorage storage $ = _getdShareStorage();
        return $._symbol;
    }

    /// @notice Contract to restrict transfers
    function transferRestrictor() public view returns (ITransferRestrictor) {
        dShareStorage storage $ = _getdShareStorage();
        return $._transferRestrictor;
    }

    /// ------------------ Setters ------------------ ///

    /// @notice Set token name
    /// @dev Only callable by owner or deployer
    function setName(string calldata newName) external onlyRole(DEFAULT_ADMIN_ROLE) {
        dShareStorage storage $ = _getdShareStorage();
        $._name = newName;
        emit NameSet(newName);
    }

    /// @notice Set token symbol
    /// @dev Only callable by owner or deployer
    function setSymbol(string calldata newSymbol) external onlyRole(DEFAULT_ADMIN_ROLE) {
        dShareStorage storage $ = _getdShareStorage();
        $._symbol = newSymbol;
        emit SymbolSet(newSymbol);
    }

    /// @notice Set transfer restrictor contract
    /// @dev Only callable by owner
    function setTransferRestrictor(ITransferRestrictor newRestrictor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        dShareStorage storage $ = _getdShareStorage();
        $._transferRestrictor = newRestrictor;
        emit TransferRestrictorSet(newRestrictor);
    }

    /// ------------------ Minting and Burning ------------------ ///

    /// @notice Mint tokens
    /// @param to Address to mint tokens to
    /// @param value Amount of tokens to mint
    /// @dev Only callable by approved minter and deployer
    /// @dev Not callable after split
    function mint(address to, uint256 value) external onlyRole(MINTER_ROLE) {
        _mint(to, value);
    }

    /// @notice Burn tokens
    /// @param value Amount of tokens to burn
    /// @dev Only callable by approved burner
    /// @dev Deployer can always burn after split
    function burn(uint256 value) external onlyRole(BURNER_ROLE) {
        _burn(msg.sender, value);
    }

    /// ------------------ Transfers ------------------ ///

    /// @inheritdoc ERC20
    function _beforeTokenTransfer(address from, address to, uint256) internal view override {
        // Disallow transfers to the zero address
        if (to == address(0) && msg.sig != this.burn.selector) revert Unauthorized();

        // If transferRestrictor is not set, no restrictions are applied
        dShareStorage storage $ = _getdShareStorage();
        ITransferRestrictor _transferRestrictor = $._transferRestrictor;
        if (address(_transferRestrictor) != address(0)) {
            // Check transfer restrictions
            _transferRestrictor.requireNotRestricted(from, to);
        }
    }

    /**
     * @param account The address of the account
     * @return Whether the account is blacklisted
     * @dev Returns true if the account is blacklisted , if the account is the zero address
     */
    function isBlacklisted(address account) external view returns (bool) {
        dShareStorage storage $ = _getdShareStorage();
        ITransferRestrictor _transferRestrictor = $._transferRestrictor;
        if (address(_transferRestrictor) == address(0)) return false;
        return _transferRestrictor.isBlacklisted(account);
    }
}
