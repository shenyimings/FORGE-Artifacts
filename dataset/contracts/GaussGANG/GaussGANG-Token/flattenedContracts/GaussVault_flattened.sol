// File contracts/dependencies/utilities/Initializable.sol


/*  This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
    behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
    external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
    function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 
    TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
         possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 
    CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
             that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {
    
    // Indicates that the contract has been initialized.
    bool private _initialized;


    // Indicates that the contract is in the process of being initialized.
    bool private _initializing;


    //Modifier to protect an initializer function from being invoked twice.
    modifier initializer() {
        
        require(_initializing || !_initialized, "Initializable: contract is already initialized");
        bool isTopLevelCall = !_initializing;
        
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }
}



// File contracts/dependencies/utilities/Context.sol


// Provides information about the current execution context, including the sender of the transaction and its data.
abstract contract Context is Initializable  {
    
    
    // Empty initializer, to prevent people from mistakenly deploying an instance of this contract, which should be used via inheritance.
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }
    
    // Empty internal initializer.
    function __Context_init_unchained() internal initializer {
    }


    function _msgSender() internal view virtual returns (address) {
        return (msg.sender);
    }
    
    
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    
    uint256[50] private __gap;
}



// File contracts/dependencies/interfaces/IBeacon.sol


// This is the interface that {BeaconProxy} expects of its beacon.
interface IBeacon {
    
    //Must return an address that can be used as a delegate call target. {BeaconProxy} will check that this address is a contract.
    function implementation() external view returns (address);
}



// File contracts/dependencies/libraries/Address.sol


// Collection of functions related to the address type.
library Address {
    
    /*  Returns true if `account` is a contract.

            - It is unsafe to assume that an address for which this function returns
                false is an externally-owned account (EOA) and not a contract.
     
            - Among others, `isContract` will return false for the following
                types of addresses:
     
                - an externally-owned account
                - a contract in construction
                - an address where a contract will be created
                - an address where a contract lived, but was destroyed
    */
    function isContract(address account) internal view returns (bool) {
        
        // This method relies on extcodesize, which returns 0 for contracts in construction,
        //  since the code is only stored at the end of the constructor execution.
        uint256 size;
        
        assembly {
            size := extcodesize(account)
        }
        
        return size > 0;
    }

    
    // Replacement for Solidity's `transfer`: sends `amount` jager to `recipient`, forwarding all available gas and reverting on errors.
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, 'Address: insufficient balance');

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }


    /*  Performs a Solidity function call using a low level `call`. A 'plaincall' is an unsafe replacement for a function call: use this function instead.
            - If `target` reverts with a revert reason, it is bubbled up by this function (like regular Solidity function calls).
            - Returns the raw returned data.
     
            Requirements:
                - `target` must be a contract.
                - calling `target` with `data` must not revert.
    */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, 'Address: low-level call failed');
    }


    //  Same as `functionCall`, but with `errorMessage` as a fallback revert reason when `target` reverts.
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }


    /*  Same as 'functionCall`, but also transferring `value` jager to `target`.
     
        Requirements:
            - the calling contract must have an BNB balance of at least `value`.
            - the called Solidity function must be `payable`.

    */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }


    // Same as `functionCallWithValue`, but with `errorMessage` as a fallback revert reason when `target` reverts.
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {        
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");
        
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    
    
    // Same as `functionCall`, but performing a static call.
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }


    // Same as `functionCall` with `errorMessage`, but performing a static call.
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }


    // Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the revert reason using the provided one.
    function verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) internal pure returns (bytes memory) {
        
        if (success) {
            return returndata;
        } 
        
        else {
            
            // Look for revert reason and bubble it up if present.
            if (returndata.length > 0) {

                // The easiest way to bubble the revert reason is using memory via assembly.
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } 
            
            else {
                revert(errorMessage);
            }
        }
    }
}



// File contracts/dependencies/libraries/StorageSlot.sol


/*  Library for reading and writing primitive types to specific storage slots.
 
    Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
    This library helps with reading and writing to such slots without the need for inline assembly.
 
    The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
    
    (Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`.)
*/
library StorageSlot {
    
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }


    //Returns an `AddressSlot` with member `value` located at `slot`.
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }


    // Returns an `BooleanSlot` with member `value` located at `slot`.
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly {
            r.slot := slot
        }
    }


    // Returns an `Bytes32Slot` with member `value` located at `slot`.
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly {
            r.slot := slot
        }
    }


    // Returns an `Uint256Slot` with member `value` located at `slot`.
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly {
            r.slot := slot
        }
    }
}



// File contracts/dependencies/utilities/BEP20Upgrade.sol


//  This abstract contract provides getters and event emitting update functions for slots.
abstract contract BEP20Upgrade is Initializable {

    function __BEP20Upgrade_init() internal initializer {
        __BEP20Upgrade_init_unchained();
    }

    function __BEP20Upgrade_init_unchained() internal initializer {
    }
    
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1.
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;
    
    // Storage slot with the address of the current implementation. 
    // This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is validated in the constructor.
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // Emitted when the implementation is upgraded.
    event Upgraded(address indexed implementation);


    // Returns the current implementation address.
    function _getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }


    // Stores a new address in the EIP1967 implementation slot.
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    
    // Perform implementation upgrade. Emits an {Upgraded} event.
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }


    // Perform implementation upgrade with additional setup call. Emits an {Upgraded} event.
    function _upgradeToAndCall(address newImplementation, bytes memory data, bool forceCall) internal {
        _upgradeTo(newImplementation);
        
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(newImplementation, data);
        }
    }


    // Perform implementation upgrade with security checks for UUPS proxies, and additional setup call. Emits an {Upgraded} event.
    function _upgradeToAndCallSecure(address newImplementation, bytes memory data, bool forceCall) internal {
        address oldImplementation = _getImplementation();

        // Initial upgrade and setup call.
        _setImplementation(newImplementation);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(newImplementation, data);
        }

        // Perform rollback test if not already in progress.
        StorageSlot.BooleanSlot storage rollbackTesting = StorageSlot.getBooleanSlot(_ROLLBACK_SLOT);
        if (!rollbackTesting.value) {
            
            // Trigger rollback using upgradeTo from the new implementation.
            rollbackTesting.value = true;
            _functionDelegateCall(
                newImplementation,
                abi.encodeWithSignature("upgradeTo(address)", oldImplementation)
            );
            rollbackTesting.value = false;
            
            // Check rollback was effective.
            require(oldImplementation == _getImplementation(), "ERC1967Upgrade: upgrade breaks further upgrades");
            
            // Finally reset to the new implementation and log the upgrade.
            _upgradeTo(newImplementation);
        }
    }
    

    // Storage slot with the admin of the contract. 
    // This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is validated in the constructor.
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;


    // Emitted when the admin account has changed.
    event AdminChanged(address previousAdmin, address newAdmin);


    // Returns the current admin.
    function _getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
    }


    // Stores a new address in the EIP1967 admin slot.
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }


    // Changes the admin of the proxy. Emits an {AdminChanged} event.
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }


    // The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
    // This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;


    // Emitted when the beacon is upgraded.
    event BeaconUpgraded(address indexed beacon);


    // Returns the current beacon.
    function _getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(_BEACON_SLOT).value;
    }


    // Stores a new beacon in the EIP1967 beacon slot.
    function _setBeacon(address newBeacon) private {
        require(Address.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(Address.isContract(IBeacon(newBeacon).implementation()),"ERC1967: beacon implementation is not a contract");
        
        StorageSlot.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }


    /*  Perform beacon upgrade with additional setup call. Emits a {BeaconUpgraded} event.
        
        Note: This upgrades the address of the beacon, it does not upgrade the implementation contained in the beacon.
                (see {UpgradeableBeacon-_setImplementation} for that).                                              */
    function _upgradeBeaconToAndCall(address newBeacon, bytes memory data, bool forceCall) internal {
        
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        }
    }


    // Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`], but performing a delegate call.
    function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
        require(Address.isContract(target), "Address: delegate call to non-contract");

        /// @custom:oz-upgrades-unsafe-allow delegatecall
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return Address.verifyCallResult(success, returndata, "Address: low-level delegate call failed");
    }
    uint256[50] private __gap;
}



// File contracts/dependencies/utilities/UUPSUpgradeable.sol


/*  An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
    {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 
    A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
    reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
    `UUPSUpgradeable` with a custom implementation of upgrades.
 
    NOTE:   The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
*/
abstract contract UUPSUpgradeable is Initializable, BEP20Upgrade {

    function __UUPSUpgradeable_init() internal initializer {
        __BEP20Upgrade_init_unchained();
        __UUPSUpgradeable_init_unchained();
    }
    

    function __UUPSUpgradeable_init_unchained() internal initializer {}


    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);    

    /*  Check that the execution is being performed through a delegatecall call and that the execution context is
        a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
        for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
        function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to fail.
    */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    
    /* Upgrade the implementation of the proxy to `newImplementation`.
            - Calls {_authorizeUpgrade}; Emits an {Upgraded} event. */
    function upgradeTo(address newImplementation) external virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallSecure(newImplementation, new bytes(0), false);
    }


    /*  Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call encoded in `data`.
            - Calls {_authorizeUpgrade}; Emits an {Upgraded} event.                                                                 */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallSecure(newImplementation, data, true);
    }
    

    // Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by {upgradeTo} and {upgradeToAndCall}.
    function _authorizeUpgrade(address newImplementation) internal virtual;
}



// File contracts/dependencies/access/Ownable.sol


// Provides a basic access control mechanism, where an account '_owner' can be granted exclusive access to specific functions by using the modifier `onlyOwner`.
abstract contract Ownable is Initializable, Context {
    
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    // Initializes the contract, setting the deployer as the initial owner.
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    
    // Initializes the contract, setting the deployer as the initial owner.
    function __Ownable_init_unchained() internal initializer {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }
    

    // Returns the address of the current owner.
    function owner() public view returns (address) {
        return _owner;
    }

    
    // Throws if called by any account other than the owner.
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }


    // Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }


    // Internal function, transfers ownership of the contract to a new account (`newOwner`).
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}



// File contracts/dependencies/interfaces/IBEP20.sol


// BEP20 Interface that creates basic functions for a BEP20 token.
interface IBEP20 {
    
    
    // Returns the amount of tokens in existence.
    function totalSupply() external view returns (uint256);
    
    
    // Returns the token decimals.
    function decimals() external view returns (uint8);
    
    
    // Returns the token symbol.
    function symbol() external view returns (string memory);
    
    
    // Returns the token name.
    function name() external view returns (string memory);
    
    
    // Returns balance of the referenced 'account' address.
    function balanceOf(address account) external view returns (uint256);


    // Transfers an 'amount' of tokens from the caller's account to the referenced 'recipient' address. Emits a {Transfer} event. 
    function transfer(address recipient, uint256 amount) external returns (bool);
    
    
    // Transfers an 'amount' of tokens from the 'sender' address to the 'recipient' address. Emits a {Transfer} event.
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);


    // Returns the remaining tokens that the 'spender' address can spend on behalf of the 'owner' address through the {transferFrom} function.
    function allowance(address _owner, address spender) external view returns (uint256);
   
    
    // Sets 'amount' as the allowance of 'spender' then returns a boolean indicating result of operation. Emits an {Approval} event.
    function approve(address spender, uint256 amount) external returns (bool);

  
    // Emitted when `value` tokens are moved from one account address (`from`) to another (`to`). Note that `value` may be zero.
    event Transfer(address indexed from, address indexed to, uint256 value);


    // Emitted when the allowance of a `spender` for an `owner` is set by a call to {approve}. `value` is the new allowance.
    event Approval(address indexed owner, address indexed spender, uint256 value);
}



// File contracts/dependencies/contracts/TokenLock.sol


// Creates a Time Lock contract for tokens transferred to it, releasing tokens after the specified "_releaseTime".
contract TokenLock is Context {
    
    using Address for address;

    // BEP20 basic token contract being held.
    IBEP20 private immutable _token;
    
    // Sender of tokens to be Time Locked.
    address private immutable _sender;

    // Beneficiary of tokens after they are released.
    address private immutable _beneficiary;

    // Timestamp when token release is enabled.
    uint256 private immutable _releaseTime;
    
    // Sets amount to be transfered into TokenLock contract.
    uint256 private _amount;


    // The constructor sets internal the values of _token, _beneficiary, and _releaseTime to the variables passed in when called externally.
    constructor(IBEP20 token_, address sender_, address beneficiary_, uint256 amount_, uint256 releaseTime_) {
        _token = token_;
        _sender = sender_;
        _beneficiary = beneficiary_;
        _amount = amount_;
        _releaseTime = (block.timestamp + releaseTime_);
    }

    
    // Returns the address that this TokenLock contract is deployed to.
    function contractAddress() public view returns (address) {
        return address(this);
    }


    // Returns the token being held.
    function token() public view returns (IBEP20) {
        return _token;
    }
    

    // Returns the beneficiary of the tokens.
    function sender() public view returns (address) {
        return _sender;
    }
    

    // Returns the beneficiary of the tokens.
    function beneficiary() public view returns (address) {
        return _beneficiary;
    }
    
    
    // Returns the amount being held in the TokenLock contract.
    function lockedAmount() public view returns (uint256) {
        return _amount;
    }


    // Returns the time when the tokens are released.
    function releaseTime() public view returns (uint256) {
        return _releaseTime;
    }


    // Transfers tokens held by TimeLock to beneficiary.
    function release() public {
        
        require (block.timestamp >= releaseTime(), "TokenLock: release time is before current time");

        uint256 amount = token().balanceOf(address(this));
        require(amount > 0, "TokenLock: no tokens to release");

        token().transfer(beneficiary(), amount);
        _amount = 0;
    }
}



// File contracts/dependencies/contracts/ScheduledTokenLock.sol


// Creates a Scheduled Time Lock contract for tokens transferred to it, releasing tokens over specific "lockTimes".
contract ScheduledTokenLock is Context {

    using Address for address;

    // BEP20 basic token contract being held.
    IBEP20 private immutable _token;
    
    // Sender of tokens to be Time Locked.
    address private immutable _sender;

    // Beneficiary of tokens after they are released.
    address private immutable _beneficiary;

    // Timestamp when token release is enabled.
    uint256 private _releaseTime;
    
    // Sets amount to be transfered into Time Lock contract.
    uint256 private _lockedAmount;
    
    // Incremental Counter to keep track of the Lock Timestamp.
    uint private _lockCounter = 0;
    
    // Initializes the amounts to be released over time.
    uint256[] private _tokenAmountsList;
        
    // Initializes the time periods that tokens will be released over.
    uint256[] private _tokenLockTimes;

    // Creates a varaible that marks the start of the Time Lock.
    uint256 private _startTime;
    

    // The constructor sets internal the values of _token, _beneficiary, _tokenAmountsList, and _tokenLockTimes to the variables passed in when called externally.
    constructor(IBEP20 token_, address sender_, address beneficiary_, uint256 amount_, uint256[] memory amountsList_, uint256[] memory lockTimes_) {
        _token = token_;
        _sender = sender_;
        _beneficiary = beneficiary_;
        _lockedAmount = amount_;
        _tokenAmountsList = amountsList_;
        _tokenLockTimes = lockTimes_;
        _startTime = block.timestamp;
        _releaseTime = (_startTime + _tokenLockTimes[0]);
    }
    

    // Returns the address that this ScheduledTokenLock contract is deployed to.
    function contractAddress() public view returns (address) {
        return address(this);
    }


    // Returns the token being held.
    function token() public view returns (IBEP20) {
        return _token;
    }
    

    // Returns the beneficiary of the tokens.
    function sender() public view returns (address) {
        return _sender;
    }
    

    // Returns the beneficiary of the tokens.
    function beneficiary() public view returns (address) {
        return _beneficiary;
    }
    
    
    // Returns the amount being held in the TimeLock contract.
    function lockedAmount() public view returns (uint256) {
        return _lockedAmount;
    }


    // Returns the time when the tokens are released.
    function releaseTime() public view returns (uint256) {
        return _releaseTime;
    }


    // Transfers tokens held by TimeLock to beneficiary.
    function release() public {
        
        require(_lockedAmount > 0, "ScheduledTokenLock: no tokens left in contract" );
        require (block.timestamp >= releaseTime(), "ScheduledTokenLock: release time is before current time");
        
        uint256 amount = _tokenAmountsList[_lockCounter];
        require(amount > 0, "ScheduledTokenLock: no tokens to release");

        token().transfer(beneficiary(), amount);
        
        _lockCounter = _lockCounter + 1;
        _lockedAmount = _lockedAmount - amount;

        // Sanitation check to prevent out of bounds exceptions before changing the "releaseTime".
        if (_lockCounter < _tokenLockTimes.length) {
            _releaseTime = (_startTime + _tokenLockTimes[_lockCounter]);
        }
    }
}



// File contracts/token/GaussVault.sol

/*  _____________________________________________________________________________

    GaussVault: Initial Token Distribution and Time Lock Controller

    Deployed to: TODO

    MIT License. (c) 2021 Gauss Gang Inc. 

    _____________________________________________________________________________
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;


/*  Initial Token Distribution and Time Lock Contract for the Gauss(GANG) token.
        - Acts as the "owner" for each TokenLock and ScheduledTokenLock that it deploys.
        - There is a public function "releaseAvailableTokens()" that can be called to release any available token in all deployed contracts.
        - Allows the "owner" of this contract to add more TokenLocks or ScheduledTokenLocks at a later date (should their be sufficient tokens held by this contract).
*/
contract GaussVault is Initializable, Context, Ownable, UUPSUpgradeable {

    // Dev-Note: Solidity 0.8.0 added built-in support for checked math, therefore the "SafeMath" library is no longer needed.
    using Address for address;

    // Initializes an event that will be called after each VestingLock contract is deployed.
    event VestingCreated(address beneficiary, address lockAddress, uint256 initialAmount);

    // Initializes two arrays that will hold the deployed contracts of both Simple and Scheduled Time Locks.
    TokenLock[] private _simpleVestingContracts;
    ScheduledTokenLock[] private _scheduledVestingContracts;

    // Initializes variables to hold the address "sender" of the tokens to be transferred, as well as the address that the Gauss(GANG) is deployed to.
    address private _senderAddress;
    IBEP20  private _gaussToken;
    bool private _previouslyLocked;
    uint256 private _decimalsAmount;
    

    /*  The initializer sets internal the values of for the Gauss(GANG) token and _senderAddress
            as well as calling the internal functions that create a Vesting Lock contract for each Pool of tokens. */
    function initialize(address gaussGANGAddress) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init(); 
        __GaussVault_init_unchained(gaussGANGAddress);
    }


    /*  The initializer sets internal the values of for the Gauss(GANG) token and _senderAddress
            as well as calling the internal functions that create a Vesting Lock contract for each Pool of tokens. */
    function __GaussVault_init_unchained(address gaussGANGAddress) internal initializer {
        _senderAddress = address(this);
        _gaussToken = IBEP20(gaussGANGAddress);
        _previouslyLocked = false;
        _decimalsAmount = (10 ** _gaussToken.decimals());
    }


    // Receive function to recieve BNB, necessary to cover gas fees.
    receive() external payable {}


    /*  Calls the internal functions that create a Vesting Lock contract for each Pool of tokens.
            NOTE:   - Must be called from "owner".
                    - Owner of GaussGANG Token must transfer the total supply, 250,000,000 tokens, to this contract address before calling function. */
    function lockGaussVault() public onlyOwner() {

        if (_previouslyLocked == false) {
            _lockCommunityTokens();
            _lockLiquidityTokens();
            _lockCharitableFundTokens();
            _lockAdvisorTokens();
            _lockCoreTeamTokens();
            _lockMarketingTokens();
            _lockOpsDevTokens();
            _lockVestingIncentiveTokens();
            _lockReserveTokens();

            _previouslyLocked = true;
        }
    }


    // Returns the beneficiary wallet address of each Vesting Lock, can be called by anyone.
    function beneficiaryVestingAddresses() public view returns (address[] memory) {

        uint256 numberOfAddresses = (_simpleVestingContracts.length + _scheduledVestingContracts.length);
        address[] memory beneficiaryWallets = new address[](numberOfAddresses);

        for (uint256 i = 0; i < numberOfAddresses; i++) {
            if (i < _simpleVestingContracts.length) {
                beneficiaryWallets[i] = _simpleVestingContracts[i].beneficiary();
            }
            else {
                beneficiaryWallets[i] = _scheduledVestingContracts[i].beneficiary();
            }
        }

        return beneficiaryWallets; 
    }


    // Returns the addresses of each Vesting Contract deployed, can be called by anyone.
    function vestingContractAddresses() public view returns (address[] memory) {

        uint256 numberOfAddresses = (_simpleVestingContracts.length + _scheduledVestingContracts.length);
        address[] memory contractAddresses = new address[](numberOfAddresses);

        for (uint256 i = 0; i < numberOfAddresses; i++) {
            if (i < _simpleVestingContracts.length) {
                contractAddresses[i] = _simpleVestingContracts[i].contractAddress();
            }
            else {
                contractAddresses[i] = _scheduledVestingContracts[i].contractAddress();
            }
        }

        return contractAddresses; 
    }


    /*  Attempts to release every wallet, ultimately releasing the available amount per Token Lock Contract.
            - Only releases a wallet if the release time for said wallet has passed.                       */
    function releaseAvailableTokens() external onlyOwner() {

        uint256 numberOfAddresses = (_simpleVestingContracts.length + _scheduledVestingContracts.length);

        for (uint256 i = 0; i < numberOfAddresses; i++) {
            if (i < _simpleVestingContracts.length) {
                if (block.timestamp >= _simpleVestingContracts[i].releaseTime()) {
                    _simpleVestingContracts[i].release();
                }
            }
            else {
                if (block.timestamp >= _scheduledVestingContracts[i].releaseTime()) {
                    _scheduledVestingContracts[i].release();
                }
            }
        }
    }


    // Returns releaseTimes for each TokenLock Contract.
    function showReleaseTimes() external view returns (address[] memory, uint256[] memory) {

        uint256 numberOfAddresses = (_simpleVestingContracts.length + _scheduledVestingContracts.length);
        address[] memory beneficiaryWallets = new address[](numberOfAddresses);
        uint256[] memory releaseTimes = new uint256[](numberOfAddresses);

        for (uint256 i = 0; i < numberOfAddresses; i++) {
            if (i < _simpleVestingContracts.length) {
                beneficiaryWallets[i] = _simpleVestingContracts[i].contractAddress();
                releaseTimes[i] = _simpleVestingContracts[i].releaseTime();
            }
            else {
                beneficiaryWallets[i] = _scheduledVestingContracts[i].contractAddress();
                releaseTimes[i] = _scheduledVestingContracts[i].releaseTime();
            }
        }

        return (beneficiaryWallets, releaseTimes); 
    }


    // Vests the specified beneficiary wallet address for the given time, Function can only be called by "owner". Returns the address the contract is deployed to. 
    function vestTokens(address sender, address beneficiary, uint256 amount, uint256 releaseTime) public onlyOwner() returns (address) {

        // Creates an instance of a TokenLock contract.
        TokenLock newVestedLock = new TokenLock(_gaussToken, sender, beneficiary, amount, releaseTime);

        // Transfers the tokens to the TokenLock contract, locking the tokens until the releaseTime is met.
        // Also adds the deployed contract to an array of all deployed Simple Token Lock contracts.
        _gaussToken.transfer(newVestedLock.contractAddress(), amount);
        _simpleVestingContracts.push(newVestedLock);

        emit VestingCreated(beneficiary, newVestedLock.contractAddress(), amount);
        return newVestedLock.contractAddress();
    }


    // Vests the specified beneficiary wallet address for the given time, Function can only be called by "owner". Returns the address the contract is deployed to. 
    function scheduledVesting(address sender, address beneficiary, uint256 amount, uint256[] memory amountsList, uint256[] memory lockTimes) public onlyOwner() returns (address) {

        require(amountsList.length == lockTimes.length, "scheduledVesting(): amountsList and lockTimes do not containt the same number of items");

        // Creates an instance of a ScheduledTokenLock contract.
        ScheduledTokenLock newScheduledLock = new ScheduledTokenLock (
            _gaussToken,
            sender,
            beneficiary,
            amount,
            amountsList,
            lockTimes
        );

        // Transfers the tokens to the ScheduledTokenLock contract, locking the tokens over the specified schedule.
        // Also adds the address of the deployed contract to an array of all deployed Scheduled Token Lock contracts.
        _gaussToken.transfer(newScheduledLock.contractAddress(), amount);
        _scheduledVestingContracts.push(newScheduledLock);

        emit VestingCreated(beneficiary, newScheduledLock.contractAddress(), amount);
        return newScheduledLock.contractAddress();
    }


    /*  Vests the wallet holding the Community Pool funds over a specific time period.
            - Total Community Pool Tokens are 112,500,000, 45% of total supply.
            - As the wallet is unlocked, the tokens will be distributed into the community supply pool.

            Release Schedule is as follows:
                Launch, Month 0:    25,000,000 tokens released
                Months 1 - 6:       1,250,000 tokens released per month
                Months 7 - 23:      4,444,444 tokens released per month
                Month 24:           4,444,452 tokens released                                         */
    function _lockCommunityTokens() internal {

        // Initializes the variables required for the ScheduledTokenLock contract.
        address beneficiaryWallet = 0x4249B05E707FeeA3FB034071C66e5A227C230C2f;
        uint256 initialAmount = 97500000 * _decimalsAmount;     // Note: Less than total Pool size because 15 million tokens are immediately sent to the Crowdsale and thus do not get routed through the Vault.
        uint256 indexNum = 25;
        uint256[] memory releaseAmounts = new uint256[](indexNum);
        uint256[] memory releaseTimes = new uint256[](indexNum);

        // Initializes the amounts to be released over time.
        for (uint i = 0; i < indexNum; i++) {
            if (i == 0) {
                releaseAmounts[i] = 10000000 * _decimalsAmount;
            }
            else if (i >= 1 && i <= 6){
                releaseAmounts[i] = 1250000 * _decimalsAmount;
            }
            else if (i >= 7 && i <= 23) {
                releaseAmounts[i] = 4444444 * _decimalsAmount;
            }
            else {
                releaseAmounts[i] = 4444452 * _decimalsAmount;
            }
        }

        // Initializes the time periods that tokens will be released over.
        for (uint i = 0; i < indexNum; i++) {
            if (i == 0) {
                releaseTimes[i] = (1 seconds);
            }
            else {
                releaseTimes[i] = ((30 days) * i);
            }
        }

        // Deploys a SceduledTokenLock contract and transfers the tokens to said contract to be released over the above schedule.
        scheduledVesting(_senderAddress, beneficiaryWallet, initialAmount, releaseAmounts, releaseTimes);
    }


    /*  Vests the wallet holding the Liquidity Pool funds over a specific time period.
            - Total Liquidity Pool Tokens are 20,000,000, 8% of total supply.

            Release Schedule is as follows:
                Month 4:    10,000,000 tokens released
                Month 8:    10,000,000 tokens released                              */
    function _lockLiquidityTokens() internal {

        // Initializes the variables required for the ScheduledTokenLock contract.
        address beneficiaryWallet = 0x17cA40C901Af4C31Ed9F5d961b16deD9a4715505;
        uint256 initialAmount = 20000000 * _decimalsAmount;
        uint256 indexNum = 2;
        uint256[] memory releaseAmounts = new uint256[](indexNum);
        uint256[] memory releaseTimes = new uint256[](indexNum);

        // Initializes the amounts to be released over time.
        releaseAmounts[0] = 10000000 * _decimalsAmount;
        releaseAmounts[1] = 10000000 * _decimalsAmount;

        // Initializes the time periods that tokens will be released over.
        releaseTimes[0] = (120 days);
        releaseTimes[1] = (240 days);

        // Deploys a SceduledTokenLock contract and transfers the tokens to said contract to be released over the above schedule.
        scheduledVesting(_senderAddress, beneficiaryWallet, initialAmount, releaseAmounts, releaseTimes);
    }


    /*  Vests the wallet holding the Charitable Fund over a specific time period.
            - Total Charitable Fund Tokens are 15,000,000, 6% of total supply.

            Release Schedule is as follows:
                Launch, Month 0:        1,111,111 tokens released (Used to create redistribution expirement)
                Month 6 - 22:           771,605 tokens released per Month
                Month 23:               771,604 tokens released                                            */
    function _lockCharitableFundTokens() internal {

        // Initializes the variables required for the ScheduledTokenLock contract.
        address beneficiaryWallet = 0x7d74E237825Eba9f4B026555f17ecacb2b0d78fE;
        uint256 initialAmount = 15000000 * _decimalsAmount;
        uint256 indexNum = 19;
        uint256[] memory releaseAmounts = new uint256[](indexNum);
        uint256[] memory releaseTimes = new uint256[](indexNum);

        // Initializes the amounts to be released over time.
        for (uint i = 0; i < indexNum; i++) {
            if (i == 0) {
                releaseAmounts[i] = 1111111 * _decimalsAmount;
            }
            else if (i >= 1 && i <= 17){
                releaseAmounts[i] = 771605 * _decimalsAmount;
            }
            else {
                releaseAmounts[i] = 771604 * _decimalsAmount;
            }
        }

        // Initializes the time periods that tokens will be released over.
        for (uint i = 0; i < indexNum; i++) {
            if (i == 0) {
                releaseTimes[i] = (1 seconds);
            }
            else {
                releaseTimes[i] = (150 days + ((30 days) * i));
            }
        } 

        // Deploys a SceduledTokenLock contract and transfers the tokens to said contract to be released over the above schedule.
        scheduledVesting(_senderAddress, beneficiaryWallet, initialAmount, releaseAmounts, releaseTimes);
    }


    /*  Vests the wallet holding the Advisor Pool over a specific time period.
            - Total Advisor Pool Tokens are 6,500,000, 2.6% of total supply.

            Release Schedule is as follows:
                Months 0 - 24:          260,000 tokens released per Month   */
    function _lockAdvisorTokens() internal {

        // Initializes the variables required for the ScheduledTokenLock contract.
        address beneficiaryWallet = 0x3e3049A80590baF63B6aC8D74F5CbB31584059bB;
        uint256 initialAmount = 6500000 * _decimalsAmount;
        uint256 indexNum = 25;
        uint256[] memory releaseAmounts = new uint256[](indexNum);
        uint256[] memory releaseTimes = new uint256[](indexNum);

        // Initializes the amounts to be released over time.
        for (uint i = 0; i < indexNum; i++) {
            releaseAmounts[i] = 260000 * _decimalsAmount;
        }

        // Initializes the time periods that tokens will be released over.
        for (uint i = 0; i < indexNum; i++) {
            if (i == 0) {
                releaseTimes[i] = (1 seconds);
            }
            else {
                releaseTimes[i] = ((30 days) * i);
            }
        }

        // Deploys a SceduledTokenLock contract and transfers the tokens to said contract to be released over the above schedule.
        scheduledVesting(_senderAddress, beneficiaryWallet, initialAmount, releaseAmounts, releaseTimes);
    }


    /*  Vests the wallet holding the Core Team Pool over a specific time period.
            - Total Core Team Pool Tokens are 25,000,000, 10% of total supply.

            Release Schedule is as follows:
                Month 5:        6,250,000 tokens released
                Month 10:       6,250,000 tokens released
                Month 15:       6,250,000 tokens released
                Month 20:       6,250,000 tokens released                      */
    function _lockCoreTeamTokens() internal {

        // Initializes the variables required for the ScheduledTokenLock contract.
        address beneficiaryWallet = 0x747dDE9cb0b8B86ef1d221077055EE9ec4E70b89;
        uint256 initialAmount = 25000000 * _decimalsAmount;
        uint256 indexNum = 4;
        uint256[] memory releaseAmounts = new uint256[](indexNum);
        uint256[] memory releaseTimes = new uint256[](indexNum);

        // Initializes the amounts to be released over time.
        for (uint i = 0; i < indexNum; i++) {
            releaseAmounts[i] = 6250000 * _decimalsAmount;
        }

        // Initializes the time periods that tokens will be released over.
        for (uint i = 0; i < indexNum; i++) {
            releaseTimes[i] = ((150 days) + (i * 150 days));
        }

        // Deploys a SceduledTokenLock contract and transfers the tokens to said contract to be released over the above schedule.
        scheduledVesting(_senderAddress, beneficiaryWallet, initialAmount, releaseAmounts, releaseTimes);
    }


    /*  Vests the wallet holding the Marketing Funds over a specific time period.
            - Total Marketing Funds Tokens are 15,000,000, 6% of total supply.

            Release Schedule is as follows:
                Launch, Month 0:        600,000 tokens released
                Month 1 - 24:           600,000 tokens released per Month       */
    function _lockMarketingTokens() internal {

        // Initializes the variables required for the ScheduledTokenLock contract.
        address beneficiaryWallet = 0x46ceE8F5F3e30aF7b62374249907FB97563262f5;
        uint256 initialAmount = 15000000 * _decimalsAmount;
        uint256 indexNum = 25;
        uint256[] memory releaseAmounts = new uint256[](indexNum);
        uint256[] memory releaseTimes = new uint256[](indexNum);

        // Initializes the amounts to be released over time.
        for (uint i = 0; i < indexNum; i++) {
            releaseAmounts[i] = 600000 * _decimalsAmount;
        }

        // Initializes the time periods that tokens will be released over.
        for (uint i = 0; i < indexNum; i++) {
            if (i == 0) {
                releaseTimes[i] = (1 seconds);
            }
            else {
                releaseTimes[i] = ((30 days) * i);
            }
        }

        // Deploys a SceduledTokenLock contract and transfers the tokens to said contract to be released over the above schedule.
        scheduledVesting(_senderAddress, beneficiaryWallet, initialAmount, releaseAmounts, releaseTimes);
    }


    /*  Vests the wallet holding the Operations and Developement Funds over a specific time period.
            - Total Operations and Developement tokens are 15,000,000, 6% of total supply.

            Release Schedule is as follows:
                Launch, Month 0:        600,000 tokens released
                Month 1 - 24:           600,000 tokens released per Month                        */
    function _lockOpsDevTokens() internal {

        // Initializes the variables required for the ScheduledTokenLock contract.
        address beneficiaryWallet = 0xF9f41Bd5C7B6CF9a3C6E13846035005331ed940e;
        uint256 initialAmount = 15000000 * _decimalsAmount;
        uint256 indexNum = 25;
        uint256[] memory releaseAmounts = new uint256[](indexNum);
        uint256[] memory releaseTimes = new uint256[](indexNum);

        // Initializes the amounts to be released over time.
        for (uint i = 0; i < indexNum; i++) {
            releaseAmounts[i] = 600000 * _decimalsAmount;
        }

        // Initializes the time periods that tokens will be released over.
        for (uint i = 0; i < indexNum; i++) {
            if (i == 0) {
                releaseTimes[i] = (1 seconds);
            }
            else {
                releaseTimes[i] = ((30 days) * i);
            }
        }

        // Deploys a SceduledTokenLock contract and transfers the tokens to said contract to be released over the above schedule.
        scheduledVesting(_senderAddress, beneficiaryWallet, initialAmount, releaseAmounts, releaseTimes);
    }


    /*  Vests the wallet holding the Vesting Incentive Funds over a specific time period.
            - Total Vesting Incentive Tokens are 12,500,000, 5% of total supply.

            Release Schedule is as follows:
                Launch, Month 0:        500,000 tokens released
                Month 1 - 24:           500,000 tokens released per Month               */
    function _lockVestingIncentiveTokens() internal {

        // Initializes the variables required for the ScheduledTokenLock contract.
        address beneficiaryWallet = 0xe3778Db10A5E8b2Bd1B68038F2cEFA835aa46b45;
        uint256 initialAmount = 12500000 * _decimalsAmount;
        uint256 indexNum = 25;
        uint256[] memory releaseAmounts = new uint256[](indexNum);
        uint256[] memory releaseTimes = new uint256[](indexNum);

        // Initializes the amounts to be released over time.
        for (uint i = 0; i < indexNum; i++) {
            releaseAmounts[i] = 500000 * _decimalsAmount;
        }

        // Initializes the time periods that tokens will be released over.
        for (uint i = 0; i < indexNum; i++) {
            if (i == 0) {
                releaseTimes[i] = (1 seconds);   
            }
            else {
                releaseTimes[i] = ((30 days) * i);
            }
        }

        // Deploys a SceduledTokenLock contract and transfers the tokens to said contract to be released over the above schedule.
        scheduledVesting(_senderAddress, beneficiaryWallet, initialAmount, releaseAmounts, releaseTimes);
    }


    /*  Vests the wallet holding the Reserve Pool over a specific time period.
            - Total Reserve Pool Tokens are 28,500,000, 11.4% of total supply.

            Release Schedule is as follows:
                Months 0, 4, 8, 12, 16, 20:      4,750,000 tokens released per month   */
    function _lockReserveTokens() internal {

        // Initializes the variables required for the ScheduledTokenLock contract.
        address beneficiaryWallet = 0xf02fD116EEfB47E394721356B36D3350972Cc0c7;
        uint256 initialAmount = 28500000 * _decimalsAmount;
        uint256 indexNum = 6;
        uint256[] memory releaseAmounts = new uint256[](indexNum);
        uint256[] memory releaseTimes = new uint256[](indexNum);

        // Initializes the amounts to be released over time.
        for (uint i = 0; i < indexNum; i++) {
            releaseAmounts[i] = 4750000 * _decimalsAmount;
        }

        // Initializes the time periods that tokens will be released over.
        for (uint i = 0; i < indexNum; i++) {
            releaseTimes[i] = ((120 days) * i);
        }

        // Deploys a SceduledTokenLock contract and transfers the tokens to said contract to be released over the above schedule.
        scheduledVesting(_senderAddress, beneficiaryWallet, initialAmount, releaseAmounts, releaseTimes);
    }


    // Function to allow "owner" to upgarde the contract using a UUPS Proxy.
    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}
}
