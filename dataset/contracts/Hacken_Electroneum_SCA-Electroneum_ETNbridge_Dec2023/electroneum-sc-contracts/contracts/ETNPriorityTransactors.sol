// contracts/ETNPriorityTransactors.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// Import from the OpenZeppelin Contracts library
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./ETNPriorityTransactorsInterface.sol";

// Make ETNPriorityTransactors inherit from the Ownable contract
contract ETNPriorityTransactors is ETNPriorityTransactorsInterface, Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    TransactorMeta[] internal transactorList;
    mapping(string => bool) internal publicKeyMap;
    mapping(string => uint) internal keyToIndex;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    ///@dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

    function addTransactor(string memory _publicKey, bool _isWaiver, string memory _name) public onlyOwner nonReentrant {
        require(bytes(_publicKey).length == 130, "Invalid public key");  // 130 character hex string is not 65 bytes in solidity as it converts 1char:1byte
        require(bytes(_name).length > 0, "Name is empty");
        require(publicKeyMap[_publicKey] == false, "Transactor already exists");

        TransactorMeta memory t;
        t.publicKey = _publicKey;
        t.name = _name;
        t.isGasPriceWaiver = _isWaiver;
        transactorList.push(t);
        keyToIndex[_publicKey] = transactorList.length - 1;
        publicKeyMap[_publicKey] = true;
    }

    function removeTransactor(string memory _publicKey) public onlyOwner nonReentrant {
        require(bytes(_publicKey).length == 130, "Invalid public key");
        require(publicKeyMap[_publicKey] == true, "Transactor not found");

        uint index = keyToIndex[_publicKey];                                    // index of public key for transactor list that we want to remove
        TransactorMeta memory last = transactorList[transactorList.length - 1]; // get memory of last transactor in the transactor list
        keyToIndex[last.publicKey] = index;                                     // change the index of the public key found in the last slot to the index of the public key we want to remove
        transactorList[index] = last;                                           // put the last transactor in the list in place of the transactor that we're removing
        transactorList.pop();                                                   // pop the last transactor in the list because it's now in place of the transactor that's been removed

        delete(keyToIndex[_publicKey]);                                         // doesn't actually remove the key but sets the default value
        delete(publicKeyMap[_publicKey]);                                       // doesn't actually remove the key but sets the default value
    }

    function setIsWaiver(string memory _publicKey, bool _isWaiver) public onlyOwner nonReentrant {
        require(bytes(_publicKey).length == 130, "Invalid public key");
        require(publicKeyMap[_publicKey] == true, "Transactor not found");

        transactorList[keyToIndex[_publicKey]].isGasPriceWaiver = _isWaiver;
    }

    function getTransactors() public view returns (TransactorMeta[] memory) {
        return transactorList;
    }

    function getTransactorByKey(string memory _publicKey) public view returns (TransactorMeta memory) {
        require(bytes(_publicKey).length == 130, "Invalid public key");
        require(publicKeyMap[_publicKey] == true, "Transactor not found");

        return transactorList[keyToIndex[_publicKey]];
    }
}
