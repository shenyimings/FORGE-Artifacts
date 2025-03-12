pragma solidity ^0.4.15;

import "./library.sol";
import "./MiniMeToken.sol";

contract RealistoToken is MiniMeToken { 

  // we use this variable to store the number of the finalization block
  uint256 public checkpointBlock;

  // address which is allowed to trigger tokens generation
  address public mayGenerateAddr;

  // flag
  bool tokenGenerationEnabled = true; //<- added after first audit


  modifier mayGenerate() {
    require ( (msg.sender == mayGenerateAddr) &&
              (tokenGenerationEnabled == true) ); //<- added after first audit
    _;
  }

  // Constructor
  function RealistoToken(address _tokenFactory) 
    MiniMeToken(
      _tokenFactory,
      0x0,
      0,
      "Realisto Token",
      18, // decimals
      "REA",
      // SHOULD TRANSFERS BE ENABLED? -- NO
      false){
    
    controller = msg.sender;
    mayGenerateAddr = controller;
  }

  function setGenerateAddr(address _addr) onlyController{
    // we can appoint an address to be allowed to generate tokens
    require( _addr != 0x0 );
    mayGenerateAddr = _addr;
  }


  /// @notice this is default function called when ETH is send to this contract
  ///   we use the campaign contract for selling tokens
  function () payable {
    revert();
  }

  
  /// @notice This function is copy-paste of the generateTokens of the original MiniMi contract
  ///   except it uses mayGenerate modifier (original uses onlyController)
  /// this is because we don't want the Sale campaign contract to be the controller
  function generate_token_for(address _addrTo, uint _amount) mayGenerate returns (bool) {
    
    //balances[_addr] += _amount;
   
    uint curTotalSupply = totalSupply();
    require(curTotalSupply + _amount >= curTotalSupply); // Check for overflow    
    uint previousBalanceTo = balanceOf(_addrTo);
    require(previousBalanceTo + _amount >= previousBalanceTo); // Check for overflow
    updateValueAtNow(totalSupplyHistory, curTotalSupply + _amount);
    updateValueAtNow(balances[_addrTo], previousBalanceTo + _amount);
    Transfer(0, _addrTo, _amount);
    return true;
  }

  // overwrites the original function
  function generateTokens(address _owner, uint _amount
    ) onlyController returns (bool) {
    revert();
    generate_token_for(_owner, _amount);    
  }


  // permanently disables generation of new tokens
  function finalize() mayGenerate {
    tokenGenerationEnabled = false; //<- added after first audit
    checkpointBlock = block.number;
  }  
}


