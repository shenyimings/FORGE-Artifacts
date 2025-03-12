// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "https://github.com/Woonkly/MartinHSolUtils/Owners.sol";

contract Pausabled is Owners{

    bool internal _paused;
    
    
    modifier Active() {
         require( !isPaused() ,"paused");
        _;
    }

  
    function isPaused() public view returns(bool){
        return _paused;
    }
    
    
    event Paused(bool paused);
    function _setPause(bool paused) internal virtual  returns(bool){
        _paused=paused;
        emit Paused(_paused);
        return true;
    }
    
    
    function setPause(bool paused) public virtual onlyIsInOwners returns(bool){
        return _setPause( paused);
    }
    
    
    
    
}




