// SPDX-License-Identifier: MIT

/*//////////////////////////////////////////////////////////////////////////////////////////////////
*
*   _____ ____  __  __ __  __          _   _ _____  ______ _____    _____  ______ ______ _____ 
*  / ____/ __ \|  \/  |  \/  |   /\   | \ | |  __ \|  ____|  __ \  |  __ \|  ____|  ____|_   _|
* | |   | |  | | \  / | \  / |  /  \  |  \| | |  | | |__  | |__) | | |  | | |__  | |__    | |  
* | |   | |  | | |\/| | |\/| | / /\ \ | . ` | |  | |  __| |  _  /  | |  | |  __| |  __|   | |  
* | |___| |__| | |  | | |  | |/ ____ \| |\  | |__| | |____| | \ \  | |__| | |____| |     _| |_ 
*  \_____\____/|_|  |_|_|  |_/_/    \_\_| \_|_____/|______|_|  \_\ |_____/|______|_|    |_____|
*                                                                                              
*                                                                                            
*//////////////////////////////////////////////////////////////////////////////////////////////////

pragma solidity >=0.4.22 <0.9.0;

contract Migrations {
  address public owner = msg.sender;
  uint public last_completed_migration;

  modifier restricted() {
    require(
      msg.sender == owner,
      "This function is restricted to the contract's owner"
    );
    _;
  }

  function setCompleted(uint completed) public restricted {
    last_completed_migration = completed;
  }
}
