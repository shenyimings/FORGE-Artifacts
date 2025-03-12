pragma solidity >=0.8.16;

contract DelegateCallTest {
  address public owner;

  constructor() {
    owner = msg.sender;  
  }

  receive() external payable {}

  function _transferEth(address _to, uint256 _amount) internal {
    bool callStatus;
    assembly {
      // Transfer the ETH and store if it succeeded or not.
      callStatus := call(gas(), _to, _amount, 0, 0, 0, 0)
    }
    require(callStatus, "_transferEth: Eth transfer failed");
  }

  function setOwner(address _new) external {
    require(msg.sender == owner, "!AUTH");
    owner = _new;
  }

  function sendETH(address _recipient) external {
    require(msg.sender == owner, "!AUTH");
    _transferEth(_recipient, address(this).balance);
  }

  function testDelegateCall(address _target) external {
    (bool success, ) = _target
      .delegatecall(abi.encodeWithSignature("sendETH(address)", msg.sender));

    require(success, "failedCall");
  }
}