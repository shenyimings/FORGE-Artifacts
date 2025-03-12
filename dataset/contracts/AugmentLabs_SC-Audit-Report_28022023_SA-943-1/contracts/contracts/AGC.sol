// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title AGC is the token to be used and managed by Augmentlabs in the ecosystem with restricted permissions for normal users.
/// @author Huy Tran
contract AGC is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, PausableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    address public companyAddress;
    mapping (address => uint256) private _userBalance;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev The initialize function for upgradeable smart contract's initialization phase
    /// @param _companyAddress is the address that is the actual holder of all AGC supply.
    function initialize(address _companyAddress) external initializer {
        require(_companyAddress != address(0), "company address must not be empty");

        __ERC20_init("AGC", "AGC");
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        companyAddress = _companyAddress;
    }
    
    /// @dev Mints new tokens to a user logically. Behind the scene, the minted tokens are credited to the company address.
    /// @notice User can still view USC balance by calling the balanceOf(address) and therefore the balance displayed on wallets are still updated.
    function mint(address userAddress, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        require(amount > 0, "AGC: cannot mint zero token");
        require(userAddress != companyAddress, "AGC: company cannot update its own balance");
        _mint(companyAddress, amount);
        
        _userBalance[userAddress] += amount;
    }

    /// @dev Pause the smart contract in case of emergency
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    /// @dev unpause the smart contract when everything is safe
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @dev Forbid burning USC as no users can burn the AGC token, including the company address.
    function burn(uint256) public pure override {
        revert("burn is not allowed");
    }

    /// @dev Destroys `amount` tokens from the user address.
    /// @notice The actual address to burn is the companyAddress. We just logically reduce the userAddress's balance by performing a mathematical substraction.
    function burnFrom(address userAddress, uint256 amount) public override onlyRole(MINTER_ROLE) whenNotPaused {
        require(userAddress != address(0), "ERC20: burn from zero address");
        require(amount <= _userBalance[userAddress], "AGC: insufficient AGC to burn");

        _burn(companyAddress, amount);

        _userBalance[userAddress] -= amount;
    }

    /// @dev View a user's USC balance.
    /// @notice This acts as a proxy to the underlying _userBalance mapping, as no user will be holding AGC token other than the company address.
    function balanceOf(address userAddress) public view override returns (uint256) {
        require(userAddress != address(0), "AGC: can not view zero address");

        if (userAddress == companyAddress) {
            return super.balanceOf(companyAddress);
        }

        return _userBalance[userAddress];
    }

    /// @dev Forbid transferring USC as no users can transfer AGC tokens, including the company address.
    function transfer(address, uint256) public pure override returns (bool) {
        revert("transfer is not allowed");
    }

    /// @dev Forbid transferring USC as no users can transfer AGC tokens, including the company address.
    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert("transferFrom is not allowed");
    }

    function _authorizeUpgrade(address)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}
}