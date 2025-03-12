pragma solidity ^0.4.24;

import "./SafeMath.sol";
import "./WhitelistAdminRole.sol";

// current version: V3
contract GasDelegationWhitelist is WhitelistAdminRole {
    using SafeMath for uint;

    /****************************************************************************************************
     *
     * Constant
     *
    ****************************************************************************************************/
    address constant private Miner = 0x00000000000000000000000000000000000003E7;
    uint256 private _contractVersion = 3;

    /* V2 feature */
    // In case of gas allocation,
    // configuring gas amount for each whitelist entry cannot exceed this limitation.
    uint256 constant private GasAllocationMax = 10 ether;
    uint256 constant private DailyGasAllocation = 1 ether;
    uint256 constant private GasRefillTimeInterval = 24 hours;



    /****************************************************************************************************
     *
     * Structures
     *
    ****************************************************************************************************/


    /****************************************************************************************************
     *
     * Storage
     *
    ****************************************************************************************************/
    // State (Whitelist)
    mapping(address => bool) private _superWhitelistMap; // this is for admin, bridge-dapp, etc.
    mapping(address => bool) private _whitelistMap; // Gas-Delegation whitelist
    mapping(address => uint256) public allocatedGasMap;
    mapping(address => uint256) public gasRefilledTimeMap;

    // State (Reference to `_fundOwner`)
    address private _fundOwner;


    /****************************************************************************************************
     *
     * Modifiers
     *
    ****************************************************************************************************/
    modifier onlyMiner() {
        require(msg.sender == Miner);
        _;
    }

    modifier onlyFundOwner() {
        require(msg.sender == _fundOwner);
        _;
    }

    /****************************************************************************************************
     *
     * Events
     *
    ****************************************************************************************************/
    event FundOwnerChanged(address indexed oldFundOwner, address indexed newFundOwner);

    /****************************************************************************************************
     *
     * Constructor
     *
    ****************************************************************************************************/
    constructor(address[] memory superWhitelistEntries, address[] memory whitelistEntries,
        address fundOwnerAddress) public payable {
        require(fundOwnerAddress != address(0));

        // initialize whitelist
        for (uint16 i = 0 ; i < superWhitelistEntries.length ; i++) {
            address addr = superWhitelistEntries[i];
            if (addr == address(0)) {
                revert();
            }
            _initSuperWhitelistData(addr);
        }

        for (uint16 j = 0 ; j < whitelistEntries.length ; j++) {
            address addr2 = whitelistEntries[j];
            if (addr2 == address(0)) {
                revert();
            }
            _initWhitelistData(addr2);
        }

        _initWhitelistData(fundOwnerAddress);

        // set _fundOwner
        _fundOwner = fundOwnerAddress;
        emit FundOwnerChanged(address(0), fundOwnerAddress);
    }


    /****************************************************************************************************
     *
     * Fallback
     *
    ****************************************************************************************************/
    function () external payable {
        require(msg.data.length == 0);
    }


    /****************************************************************************************************
     *
     * Operations (read)
     *
    ****************************************************************************************************/
    function getContractVersion() public view returns (uint256) {
        return _contractVersion;
    }

    function checkWhitelist(address _addr, uint256 _gas) public returns (bool) {
        //#################################################################
        // You should know that this function is called by miner instance.
        // So, DO NOT make any changes to calling convention of it.
        //#################################################################
        require(_gas > 0);

        if (isSuperWhitelist(_addr)) {
            return true;
        } else if (_whitelistMap[_addr]) {
//            if (gasRefilledTimeMap[_addr] + GasRefillTimeInterval <= block.timestamp) {
//                allocatedGasMap[_addr] = DailyGasAllocation.sub(_gas);
//                gasRefilledTimeMap[_addr] = block.timestamp;
//                return true;
//            } else if (allocatedGasMap[_addr] >= _gas) {
//                allocatedGasMap[_addr] = allocatedGasMap[_addr].sub(_gas);
//                return true;
//            }
            return true;

            // Cannot refill gas and no more available gas left
        }

        return false;
    }

    function isSuperWhitelist(address addr) public view returns (bool) {
        return _superWhitelistMap[addr];
    }

    function isWhitelist(address addr) public view returns (bool) {
        return _whitelistMap[addr];
    }

    /****************************************************************************************************
     *
     * Operations (write)
     *
    ****************************************************************************************************/
    function refundAll() onlyFundOwner public returns (bool) {
        _fundOwner.transfer(address(this).balance);
        return true;
    }

    function refundAmount(uint256 amount) onlyFundOwner public returns (bool) {
        require(address(this).balance >= amount);

        _fundOwner.transfer(amount);
        return true;
    }

    function setFundOwner(address newFundOwnerAddress) onlyFundOwner external returns (bool) {
        require(newFundOwnerAddress != address(0));
        require(newFundOwnerAddress != _fundOwner);

        emit FundOwnerChanged(_fundOwner, newFundOwnerAddress);

        _fundOwner = newFundOwnerAddress;
        return true;
    }

    function substituteWhitelistEntry(address _oldAddr, address _newAddr, uint256 _gasAlloc /* V2
     feature */) onlyWhitelistAdmin public {
        require(_oldAddr != address(0) && _newAddr != address(0));
        require(_oldAddr != _newAddr);
        require(_gasAlloc >= 0 && _gasAlloc <= GasAllocationMax);

        if (!_whitelistMap[_oldAddr] || _whitelistMap[_newAddr]) {
            revert();
        }

        _whitelistMap[_newAddr] = true;
        allocatedGasMap[_newAddr] = allocatedGasMap[_oldAddr];
        gasRefilledTimeMap[_newAddr] = gasRefilledTimeMap[_oldAddr];

        _deleteWhitelistData(_oldAddr);
    }

    function addWhitelistEntry(address _addr, uint256 _gasAlloc /* V2 feature */) onlyWhitelistAdmin
    public {
        require(_addr != address(0));
        require(_gasAlloc >= 0 && _gasAlloc <= GasAllocationMax);

        if (_whitelistMap[_addr]) {
            revert();
        }

        _initWhitelistData(_addr);
    }

    function removeWhitelistEntry(address _addr) onlyWhitelistAdmin public {
        require(_addr != address(0));

        if (_whitelistMap[_addr]) {
            _deleteWhitelistData(_addr);
        }

        // If requested entry is not whitelisted, just ignore it.
    }

    function addSuperWhitelistEntry(address addr) onlyWhitelistAdmin external returns (bool) {
        require(addr != address(0));

        _initSuperWhitelistData(addr);
        return true;
    }

    function removeSuperWhitelistEntry(address addr) onlyWhitelistAdmin external returns (bool) {
        require(addr != address(0));

        _deleteSuperWhitelistData(addr);
        return true;
    }

    function _initWhitelistData(address _addr) internal {
        allocatedGasMap[_addr] = DailyGasAllocation;
        gasRefilledTimeMap[_addr] = block.timestamp;
        _whitelistMap[_addr] = true;
    }

    function _deleteWhitelistData(address _addr) internal {
        delete _whitelistMap[_addr];
        delete allocatedGasMap[_addr];
        delete gasRefilledTimeMap[_addr];
    }

    function _initSuperWhitelistData(address addr) internal {
        require(_superWhitelistMap[addr] == false);
        _superWhitelistMap[addr] = true;
    }

    function _deleteSuperWhitelistData(address addr) internal {
        require(_superWhitelistMap[addr] == true);
        _superWhitelistMap[addr] = false;
    }
}
