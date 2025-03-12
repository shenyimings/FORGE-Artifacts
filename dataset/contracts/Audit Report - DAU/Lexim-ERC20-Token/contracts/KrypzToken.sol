// SPDX-License-Identifier: Copyright all rights reserved.
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


/// @title A ERC20 token 
/// @dev Supports transfer fees
contract KrypzToken is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable,
 PausableUpgradeable, AccessControlUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable {
    
    /// @dev Constant for the pauser role
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    /// @dev Constant for the minter role
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /// @dev Constant for the controller role
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    /// @dev Constant for the fee controller role
    bytes32 public constant FEE_ROLE = keccak256("FEE_ROLE");

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");


    // Token name
    string private _changeableName;

    // Token symbol
    string private _changeableSymbol;

    // Token symbol
    /// @dev Name of the token when deployed
    string public originalName;

    mapping(address => bool) internal _frozen;
    mapping(address => bool) internal _notpaying;    


    /// @dev Current fee rate
    uint256 public feeRate;
    /// @dev Address where fees get sent
    address public feeAccumulator;


    /// @dev Fee rate denominator
    uint256 public feeParts;
    /// @dev Stuct to support dynamic list of goldbar ids
    struct Set {
        string[] values;
        mapping (string => uint) isIn;
    }

    Set internal _goldBars; 
    

    /**
     * @dev Emitted when `addr` has been frozen
     */
    event AddressFrozen(address indexed addr);
    /**
     * @dev Emitted when `addr` has been unfrozen
     */
    event AddressUnfrozen(address indexed addr);
    /**
     * @dev Emitted in addition to transfer event during transfer when fee is being transfered to accumulator
     */
    event FeeCollected(address indexed from, address indexed to, uint256 value);
    /**
     * @dev Emitted every time trasfer fee rate is changed
     */
    event FeeRateSet(
        uint256 indexed oldFeeRate,
        uint256 indexed newFeeRate
    );

    /**
     * @dev Emitted every time trasfer fee accumulator is changed
     */
    event FeeAccumulatorSet(
        address indexed oldFeeAccumulator,
        address indexed newFeeAccumulator
    );

     /**
     * @dev Gold bar id added
     */
    event GoldBarIdAdded(
        string indexed goldBarId
    );

    /**
    * @dev Gold bar id removce
    */
    event GoldBarIdRemoved(
        string indexed goldBarId
    );
/// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }


    function  initialize(string memory initialName, string memory initialSymbol) initializer public {
        __ERC20_init(initialName, initialSymbol);
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init(initialName);
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(CONTROLLER_ROLE, msg.sender);
        _grantRole(FEE_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _changeableName = initialName;
        _changeableSymbol = initialSymbol;
        originalName = initialName;
        feeRate = 0;
        feeParts = 1000000;
        feeAccumulator = msg.sender;
    }
    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view  override returns (string memory) {
        return _changeableName;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view  override returns (string memory) {
        return _changeableSymbol;
    }
    /**
     * @dev set name and symbol
     */
    function setNameAndSymbol(string memory newName, string memory newSymbol)
     public  onlyRole(CONTROLLER_ROLE) {
        _changeableName = newName;
        _changeableSymbol = newSymbol;
    }

    /**
     * @dev returns list of goldbars. Order is NOT guaranteed to be constant.
     */
    function getGoldBars() public view returns(string[] memory) {
        return _goldBars.values;
    }

     /**
     * @dev Move the last goldbar id to the deleted spot.
     * Remove the last element.
    */
    function removeGoldBar(string calldata goldBarId) public  onlyRole(CONTROLLER_ROLE) {       
        uint pos = _goldBars.isIn[goldBarId];
        require(pos > 0, "Gold bar not found");
        string memory lastVal = _goldBars.values[_goldBars.values.length-1];
        _goldBars.values[pos-1] = _goldBars.values[_goldBars.values.length-1];
        _goldBars.values.pop();
        _goldBars.isIn[lastVal] = pos;
        emit GoldBarIdRemoved(goldBarId);
    }

    /**
     * @dev Add gold bar id to the list
    */
    function addGoldBar(string calldata goldbarId) public  onlyRole(CONTROLLER_ROLE) {
        require(_goldBars.isIn[goldbarId] == 0, "Gold bar already exists");
        _goldBars.values.push(goldbarId);
        _goldBars.isIn[goldbarId] = _goldBars.values.length;
        emit GoldBarIdAdded(goldbarId);
    }

    /**
     * @dev Add list of gold bar ids to the list
    */
    function addGoldBars(string[] calldata goldbarIds) public onlyRole(CONTROLLER_ROLE)  {
        for (uint256 i=0;i<goldbarIds.length;i++) {
            addGoldBar(goldbarIds[i]);
        }
    }

    /**
     * @dev Remove list of gold bar ids from the list
    */
     function removeGoldBars(string[] calldata goldbarIds) public onlyRole(CONTROLLER_ROLE)  {
        for (uint256 i=0;i<goldbarIds.length;i++) {
            removeGoldBar(goldbarIds[i]);
        }
    }


    /**
     * @dev Freezes an address balance from being transferred.
     * @param addr The address to freeze.
     */
    function freeze(address addr) public onlyRole(CONTROLLER_ROLE) {
        require(!_frozen[addr], "address already frozen");
        _frozen[addr] = true;
        emit AddressFrozen(addr);
    }

    /**
     * @dev Unfreezes an address balance allowing transfer.
     * @param addr The new address to unfreeze.
     */
    function unfreeze(address addr) public onlyRole(CONTROLLER_ROLE) {
        require(_frozen[addr], "address already unfrozen");
        _frozen[addr] = false;
        emit AddressUnfrozen(addr);
    }

    /**
    * @dev Gets whether the address is currently frozen.
    * @param addr The address to check if frozen.
    * @return A bool representing whether the given address is frozen.
    */
    function isFrozen(address addr) public view returns (bool) {
        return _frozen[addr];
    }

     /**
     * @dev Adds an address to the list of nonpaying addresses
     * @param addr The address to add.
     */
    function addNotPaying(address addr) public onlyRole(FEE_ROLE) {
        require(!_notpaying[addr], "address already notpaying");
        _notpaying[addr] = true;
    }

    /**
     * @dev Removes an address from notpaying.
     * @param addr The  address to remove.
     */
    function removeNotPaying(address addr) public onlyRole(FEE_ROLE) {
        require(_notpaying[addr], "address is not notpaying");
        _notpaying[addr] = false;
    }

    /**
    * @dev Gets whether the address is currently notpaying.
    * @param addr The address to check if notpaying.
    * @return A bool representing whether the given address is notpaying.
    */
    function isNotPaying(address addr) public view returns (bool) {
        return _notpaying[addr];
    }

     /**
     * Pause the contract preventing transfers
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * Unpause the contract
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public  onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
        require(!_frozen[to] && !_frozen[from], "address frozen");
    }

    /**
     * @dev Sets a new fee recipient address.
     * @param newFeeAccumulator The address allowed to collect transfer fees for transfers.
     */
    function setFeeAccumulator(address newFeeAccumulator) public onlyRole(FEE_ROLE) {
        require(newFeeAccumulator != address(0), "cannot set fee accumulator to null");
        address oldFeeAccumulator = feeAccumulator;
        feeAccumulator = newFeeAccumulator;
        emit FeeAccumulatorSet(oldFeeAccumulator, newFeeAccumulator);
    }

    /**
     * @dev Sets a new fee rate.
     * @param _newFeeRate The new fee rate to collect as transfer fees for transfers.
     */
    function setFeeRate(uint256 _newFeeRate) public onlyRole(FEE_ROLE) {
        require(_newFeeRate <= feeParts, "cannot set fee rate above 100%");
        uint256 _oldFeeRate = feeRate;
        feeRate = _newFeeRate;
        emit FeeRateSet(_oldFeeRate, feeRate);
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient` subtracting fee
     * fee is transfered to feeAccumulator
     *
     * Emits 2 {Transfer} events. Emits 2 {FeeCollected}  event
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {    
        uint256 feeAmount = 0;
        if (!_notpaying[sender] && !_notpaying[recipient]) {
            feeAmount = getFeeFor(amount);
        }
        uint256 newAmount = amount - feeAmount;
        if (feeAmount>0){
            emit FeeCollected(sender, feeAccumulator, feeAmount);
            super._transfer(sender, feeAccumulator, feeAmount);
        }
        super._transfer(sender, recipient, newAmount);
    }

    /**
    * @dev Gets a fee for a given value
    * ex: given feeRate = 200 and feeParts = 1,000,000 then getFeeFor(10000) = 2
    * @param value The amount to get the fee for.
    */
    function getFeeFor(uint256 value) public view returns (uint256) {
        if (feeRate == 0) {
            return 0;
        }
        return value*feeRate/feeParts;
    }

    function _authorizeUpgrade(address newImplementation)
    internal
    onlyRole(UPGRADER_ROLE)
    override
    {}
    
}