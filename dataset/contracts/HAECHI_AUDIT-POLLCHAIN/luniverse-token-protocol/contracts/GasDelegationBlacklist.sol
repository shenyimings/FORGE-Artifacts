pragma solidity ^0.4.24;

import "./SafeMath.sol";
import "./WhitelistAdminRole.sol";

// current version: V3
contract GasDelegationBlacklist is WhitelistAdminRole {
    using SafeMath for uint;

    /****************************************************************************************************
     *
     * Constant
     *
    ****************************************************************************************************/
    address constant private Miner = 0x00000000000000000000000000000000000003E7;
    uint256 private _contractVersion = 1;

    /* V2 feature */
    // TODO or Not: V2 feature(gas allocation)
    // In case of gas allocation,
//    uint256 constant private GasAllocationMax = 10 ether;
//    uint256 constant private DailyGasAllocation = 1 ether;
//    uint256 constant private GasRefillTimeInterval = 24 hours;



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
    // State (Blacklist)
    mapping(address => bool) private _blacklistMap;
    // TODO or Not: V2 feature(gas allocation)
//    mapping(address => uint256) public allocatedGasMap;
//    mapping(address => uint256) public gasRefilledTimeMap;

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
    constructor(address fundOwnerAddress) public payable {
        require(fundOwnerAddress != address(0));

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

        if (_blacklistMap[_addr]) {
            return false;
        }

        return true;
    }

    function isBlacklist(address addr) public view returns (bool) {
        return _blacklistMap[addr];
    }

    /****************************************************************************************************
     *
     * Operations (write)
     *
    ****************************************************************************************************/
    function refundAll() onlyFundOwner public {
        _fundOwner.transfer(address(this).balance);
    }

    function setFundOwner(address newFundOwnerAddress) onlyFundOwner external returns (bool) {
        require(newFundOwnerAddress != address(0));
        require(newFundOwnerAddress != _fundOwner);

        emit FundOwnerChanged(_fundOwner, newFundOwnerAddress);

        _fundOwner = newFundOwnerAddress;
        return true;
    }

    function substituteBlacklistEntry(address oldAddr, address newAddr) onlyWhitelistAdmin public
    returns (bool) {
        require(oldAddr != address(0) && newAddr != address(0));
        require(oldAddr != newAddr);
        require(_blacklistMap[oldAddr] && !_blacklistMap[newAddr]);

        _initBlacklistData(newAddr);
        _deleteBlacklistData(oldAddr);

        return true;
    }

    function addBlacklistEntry(address addr) onlyWhitelistAdmin external returns (bool) {
        require(addr != address(0));

        _initBlacklistData(addr);
        return true;
    }

    function removeBlacklistEntry(address addr) onlyWhitelistAdmin external returns (bool) {
        require(addr != address(0));

        // If requested entry is not whitelisted, just ignore it.
        _deleteBlacklistData(addr);
        return true;
    }

    function _initBlacklistData(address addr) internal {
        // add only if addr is not blacklisted
        require(_blacklistMap[addr] == false);

        _blacklistMap[addr] = true;
    }

    function _deleteBlacklistData(address addr) internal {
        require(_blacklistMap[addr] == true);
        delete _blacklistMap[addr];
    }
}
