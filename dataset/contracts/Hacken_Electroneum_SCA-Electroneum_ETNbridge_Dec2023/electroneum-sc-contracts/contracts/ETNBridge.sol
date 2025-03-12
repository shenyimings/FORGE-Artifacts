// contracts/ETNBridge.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// Import from the OpenZeppelin Contracts library
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

// Make ETNBridge inherit from the Ownable contract
contract ETNBridge is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {

    // Croschain mappings
    mapping(string => address) internal crosschainLegacyETNtoAddress;                   //legacy address to sc address
    mapping(address => uint256) internal crosschainBalance;                             //sc address     to balance sent out
    mapping(address => string[]) internal addressTxMap;                                 //address        to txhash array
    mapping(string => uint256) internal txMap;                                          //tx hash        to tx amount
    mapping(address => string[]) internal addressToLegacyETNAddressMap;                 // sc address    to legacy etn addresses
    mapping(address => mapping(bytes32 => bool)) internal addressToLegacyETNToExistsMap;//const time lookup if legacy ETN address is already used

    // Counter for total crosschain amount and txs
    uint256 internal totalCrosschainAmount;
    uint internal totalCrosschainTxs;
    string internal lastCrosschainLegacyTxHash;

    // Event definitions
    event CrossChainTransfer(string indexed _fromIndexed, string _from, address indexed _to, uint256 _value);
    event DepositReceived(address indexed _from, uint256 _value);

    // fallback() and receive() definition. This allows ETN to be sent to this contract address.
    fallback() external payable { require(msg.data.length == 0, ""); }
    receive() external payable onlyOwner { emit DepositReceived(msg.sender, msg.value); }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    ///@dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function pause() public whenNotPaused onlyOwner {
        PausableUpgradeable._pause();
    }

    function unpause() public whenPaused onlyOwner {
        PausableUpgradeable._unpause();
    }

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
    }

    function crosschainTransfer(address payable _address, string memory _legacyETNAddress, uint256 _amount, string memory _txHash, bool _isOracle) public onlyOwner nonReentrant whenNotPaused {
        // Address verification
        require(_address != address(0), "Invalid address");

        uint32 size;
        assembly {
            size := extcodesize(_address)
        }
        require(size == 0, "Cannot send to contract address");  // Prevent sending to contract addresses

        bytes memory tempLegacyETNBytes = bytes(_legacyETNAddress);
        require(tempLegacyETNBytes.length == 98, "Invalid legacy ETN address");
        // Amount verification
        require(_amount > 0, "Invalid amount");
        require(address(this).balance >= _amount, "Insufficient ETN balance in the bridge contract");
        //Tx hash verification
        bytes memory tempTXHashBytes = bytes(_txHash);
        require(tempTXHashBytes.length == 64, "Invalid transaction hash");
        require(txMap[_txHash] == 0, "Duplicate crosschain transaction");

        // Check the LegacyAddress <-> Address map, a legacy ETN address should be mapped to the same SC address
        if(crosschainLegacyETNtoAddress[_legacyETNAddress] != address(0)) {
            require(crosschainLegacyETNtoAddress[_legacyETNAddress] == _address, "This legacy ETN address is already mapped to a different address");
        } else {
            // Store a map of legacy etn address <-> address
            crosschainLegacyETNtoAddress[_legacyETNAddress] = _address;
        }

        // Check the Address <-> LegacyAddress map, an Address can be mapped to multiple legacy addresses
        bytes32 legacyAddressKeccak256 = keccak256(abi.encodePacked(_legacyETNAddress));
        if(addressToLegacyETNToExistsMap[_address][legacyAddressKeccak256] == false) {
            addressToLegacyETNToExistsMap[_address][legacyAddressKeccak256] = true;
            addressToLegacyETNAddressMap[_address].push(_legacyETNAddress);
        }

        // Compute total amount transacted
        totalCrosschainAmount += _amount;

        // Compute total amount transacted per address
        crosschainBalance[_address] = crosschainBalance[_address] + _amount;

        // Count crosschain tx
        totalCrosschainTxs += 1;

        // Push tx hash into address -> tx_hash[] map
        addressTxMap[_address].push(_txHash);

        // Mark tx_hash computed by storing tx amount into txMap[hash]
        txMap[_txHash] = _amount;

        if(_isOracle) {
            lastCrosschainLegacyTxHash = _txHash;
        }

        // Transfer ETN from contract to EOA
        _address.transfer(_amount);

        // Log event
        emit CrossChainTransfer(_legacyETNAddress, _legacyETNAddress, _address, _amount);
    }

    function getLegacyETNAddress(address _address) public view returns (string[] memory) {
        return addressToLegacyETNAddressMap[_address];
    }

    // Get new address from legacy etn address
    function getAddressFromLegacy(string calldata _legacyETNAddress) public view returns (address) {
        return crosschainLegacyETNtoAddress[_legacyETNAddress];
    }

    // Get transaction history for a particular address
    function getTxHistory(address _address) public view returns (string[] memory) {
        return addressTxMap[_address];
    }

    // Get amount for a particular transaction
    function getTxAmount(string calldata txHash) public view returns (uint256) {
        return txMap[txHash];
    }

    // Get total count of txs sent to this bridge contract
    function getTotalTxCount() public view returns (uint) {
        return totalCrosschainTxs;
    }

    // Get total amount of ETN sent to this bridge contract
    function getTotalCrosschainAmount() public view returns (uint256) {
        return totalCrosschainAmount;
    }

    // Get total amount of ETN migrated per address
    function getAddressCosschainAmount(address _address) public view returns (uint256) {
        return crosschainBalance[_address];
    }

    function getLastCrosschainLegacyTxHash() public view returns (string memory) {
        return lastCrosschainLegacyTxHash;
    }
}
