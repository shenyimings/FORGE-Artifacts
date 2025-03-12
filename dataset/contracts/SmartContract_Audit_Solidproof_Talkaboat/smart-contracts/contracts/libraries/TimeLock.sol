// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract TimeLock is Ownable {
    using Address for address;   
    
    /* =====================================================================================================================
                                                        Variables
    ===================================================================================================================== */
    bool public isLockEnabled = false;
    mapping(string => uint256) public timelock;
    uint256 private constant _TIMELOCK = 1 days;
    address private _maintainer;  
        
    /* =====================================================================================================================
                                                        Events
    ===================================================================================================================== */
    event MaintainerTransferred(address indexed previousMaintainer, address indexed newMaintainer);
    event UnlockedFunction(string indexed functionName, uint256 indexed unlockedAt);
    event EnabledLock();
    
    /* =====================================================================================================================
                                                        Modifier
    ===================================================================================================================== */
    //After unlock we have to wait for _TIMELOCK before we can call the Function
    //Additionally we have a time window of 24 hours to call the function to prevent pre-unlocked calls
    modifier locked(string memory _fn) {
        require(!isLockEnabled || (timelock[_fn] != 0 && timelock[_fn] <= block.timestamp && timelock[_fn] + _TIMELOCK >= block.timestamp), "Function is locked");
        _;
        lockFunction(_fn);
    }
        
    modifier onlyMaintainerOrOwner() {
        require(owner() == msg.sender || _maintainer == msg.sender, "operator: caller is not allowed to call this function");
        _;
    }

    constructor() {
        _maintainer = msg.sender;
    }
    
    /* =====================================================================================================================
                                                        Get Functions
    ===================================================================================================================== */
    function maintainer() public view returns (address) {
        return _maintainer;
    }
        
    /* =====================================================================================================================
                                                        Set Functions
    ===================================================================================================================== */
    function setMaintainer(address _newMaintainer) public onlyMaintainerOrOwner locked("maintainer") {
        require(_newMaintainer != _maintainer && _newMaintainer != address(0), "ABOAT::setMaintainer: Maintainer can\'t equal previous maintainer or zero address");
        address previousMaintainer = _maintainer;
        _maintainer = _newMaintainer;
        emit MaintainerTransferred(previousMaintainer, _maintainer);
    }
    
    function setTimelockEnabled() public onlyMaintainerOrOwner {
        isLockEnabled = true;
        emit EnabledLock();
    }

    /* =====================================================================================================================
                                                    Utility Functions
    ===================================================================================================================== */ 
    //unlock timelock
    function unlockFunction(string memory _fn) public onlyMaintainerOrOwner {
        timelock[_fn] = block.timestamp + _TIMELOCK;
        emit UnlockedFunction(_fn, timelock[_fn]);
     }
      
     //lock timelock
    function lockFunction(string memory _fn) public onlyMaintainerOrOwner {
        timelock[_fn] = 0;
    }
}