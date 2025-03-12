// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
import "../../dependencies/utilities/Context.sol";
import "../../dependencies/access/Ownable.sol";
import "../../dependencies/interfaces/IBEP20.sol";
import "../../dependencies/libraries/Address.sol";



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