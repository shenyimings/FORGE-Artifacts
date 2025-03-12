// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MigrationAgent.sol";
import "./Locked.sol";

/**
 * @title GovernanceToken
 * @dev Burnable, Mintable, Ownable, Pausable, with Locking ability per user.
 */
contract GovernanceToken is
    Pausable,
    ERC20,
    Ownable,
    ERC20Burnable,
    Locked

{
    uint8 public constant DECIMALS = 18;
    uint256 public constant INITIAL_SUPPLY = 250000000 * (10**uint256(DECIMALS));
    address public migrationAgent;
    uint256 public totalMigrated;
    
    event Migrate(address indexed from, address indexed to, uint256 value);
    event MigrationAgentSet(address indexed migrationAgent);
    event LogControllerSet(address indexed controller);
    event LogControllerRevoked(address indexed controller);



    /// @dev prevent accidental sending of tokens to this token contract
    /// @param _self - address of this contract
    modifier notSelf(address _self) {
        require(
            _self != address(this),
            "You are trying to send tokens to token contract"
        );
        _;
    }

    /// @dev Constructor that gives msg.sender all of existing tokens and initiates token.
    constructor() public ERC20("DAO Capsule", "DCAP") {
        _mint(msg.sender, INITIAL_SUPPLY);      
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @dev grant role of controller to provided address, minting, pausing, locking
    /// @param _controller - address of the entity for which role is granted
    function setController(address _controller)  public  {
        require(_controller != address(0), "Token:setController - Controller address can't be 0"); 
        grantRole(CONTROLLER_ROLE, _controller);
        emit LogControllerSet(_controller);
    }

    /// @dev revoke role of controller to provided address, minting, pausing, locking
    /// @param _controller - address of the entity for which role is revoked
    function revokeController(address _controller) public  {
        require(_controller != address(0), "Token:revokeController - Controller address can't be 0"); 
        revokeRole(CONTROLLER_ROLE, _controller);
        LogControllerRevoked(_controller);

    }

    /// @dev Function to mint tokens once per year
    /// @param to address to which new minted tokens are sent
    /// @param amount of tokens to send 
    /// @return A boolean that indicates if the operation was successful.
    function mint(address to, uint256 amount) public isController() returns (bool) {       
        require(to != address(0), "Token:mint - Recipient address can't be 0");        
        _mint(to, amount);
        return true;
    }

    /// @notice Migrate tokens to the new token contract.
    function migrate() external whenNotPaused() {
        uint256 value = balanceOf(msg.sender);
        require(migrationAgent != address(0), "Token:migrate - Enter migration agent address");
        require(value > 0, "Token:migrate - Amount of tokens is required");

        _addLock(msg.sender);
        burn(balanceOf(msg.sender));
        totalMigrated += value;
        MigrationAgent(migrationAgent).migrateFrom(msg.sender, value);
        _removeLock(msg.sender);
        emit Migrate(msg.sender, migrationAgent, value);
    }

    /// @notice Set address of migration target contract and enable migration process
    /// @param _agent The address of the MigrationAgent contract
    function setMigrationAgent(address _agent) external onlyOwner() {
        require(_agent != address(0), "Token:setMigrationAgent - Migration agent can't be 0");
        migrationAgent = _agent;
        emit MigrationAgentSet(_agent);
    }

    /// @notice Overwrite parent implementation to add locked verification and notSelf modifiers
    function transfer(address to, uint256 value)
        public
        override
        isNotLocked(msg.sender, to)
        notSelf(to)
        returns (bool)
    {
        return super.transfer(to, value);
    }

    /// @notice Overwrite parent implementation to add locked verification and notSelf modifiers
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override isNotLocked(from, to) notSelf(to) returns (bool) {
        return super.transferFrom(from, to, value);
    }

    /// @notice Overwrite parent implementation to add locked verification and notSelf modifiers
    function approve(address spender, uint256 value)
        public
        override
        isNotLocked(msg.sender, spender)
        notSelf(spender)
        returns (bool)
    {
        return super.approve(spender, value);
    }

    /// @notice Overwrite parent implementation to add locked verification and notSelf modifiers
    function increaseAllowance(address spender, uint256 addedValue)
        public
        override
        isNotLocked(msg.sender, spender)
        notSelf(spender)
        returns (bool success)
    {
        return super.increaseAllowance(spender, addedValue);
    }

    /// @notice Overwrite parent implementation to add locked verification and notSelf modifiers
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        override
        isNotLocked(msg.sender, spender)
        notSelf(spender)
        returns (bool success)
    {
        return super.decreaseAllowance(spender, subtractedValue);
    }

    function pause() public isController()  {       
        super._pause();
    }

    function unpause() public  isController() {        
        super._unpause();
    }
}
