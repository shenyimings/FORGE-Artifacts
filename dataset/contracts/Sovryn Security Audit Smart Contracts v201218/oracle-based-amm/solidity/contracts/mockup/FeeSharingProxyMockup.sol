pragma solidity 0.4.26;

contract FeeSharingProxyMockup {
  event TokensTransferred(address indexed sender, address indexed token, uint256 amount);

  function transferTokens(address _token, uint96 _amount) public {
    emit TokensTransferred(msg.sender, _token, _amount);
  }

  function withdrawFees(address _converter, address _receiver) public {
    IConverterMockup(_converter).withdrawFees(_receiver);
  }
}

interface IConverterMockup {
  function withdrawFees(address receiver) public;
}