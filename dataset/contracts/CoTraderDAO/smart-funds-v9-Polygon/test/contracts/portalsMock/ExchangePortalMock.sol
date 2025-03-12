pragma solidity ^0.6.12;

import "../../../contracts/zeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../../../contracts/core/interfaces/IMerkleTreeTokensVerification.sol";
import "../../../contracts/zeppelin-solidity/contracts/math/SafeMath.sol";

contract ExchangePortalMock {

  using SafeMath for uint256;
  // Contract for merkle tree white list verification
  IMerkleTreeTokensVerification public merkleTreeWhiteList;

  // This contract recognizes ETH by this address, airswap recognizes ETH as address(0x0)
  IERC20 constant private ETH_TOKEN_ADDRESS = IERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);
  address constant private NULL_ADDRESS = address(0);
  // multiplyer and divider are used to set prices. X ether = X*(mul/div) token,
  // similarly X token = X*(div/mul) ether for every token where X is the amount
  uint256 public mul;
  uint256 public div;
  address public stableCoinAddress;
  bool public stopTransfer;


  // Enum
  enum ExchangeType { Paraswap, Bancor, OneInch }

  event Trade(address trader, address src, uint256 srcAmount, address dest, uint256 destReceived, uint8 exchangeType);

  constructor(
    uint256 _mul,
    uint256 _div,
    address _stableCoinAddress,
    address _merkleTreeWhiteList
    )
    public
  {
    mul = _mul;
    div = _div;
    stableCoinAddress = _stableCoinAddress;
    merkleTreeWhiteList = IMerkleTreeTokensVerification(_merkleTreeWhiteList);
  }

  function trade(
    IERC20 _source,
    uint256 _sourceAmount,
    IERC20 _destination,
    uint256 _type,
    bytes32[] calldata _proof,
    uint256[] calldata _positions,
    bytes calldata _additionalData,
    bool _verifyDestanation
  ) external payable returns (uint256) {
    require(_source != _destination);

    uint256 receivedAmount;

    // throw if destanation token not in white list
    if(_verifyDestanation)
      _verifyToken(address(_destination), _proof, _positions);

    // check ETH payable case
    if (_source == ETH_TOKEN_ADDRESS) {
      require(msg.value == _sourceAmount);
    } else {
      require(msg.value == 0);
    }

    if (_type == uint(ExchangeType.Paraswap)) {
      // Trade via Paraswap
      receivedAmount = _tradeViaParaswapMock(_source, _destination, _sourceAmount, _additionalData);
    }
    else if (_type == uint(ExchangeType.Bancor)) {
      // Trade via Bancor (We can add special logic fo Bancor here)
      receivedAmount = _trade(_source, _destination, _sourceAmount);
    }
    else if (_type == uint(ExchangeType.OneInch)) {
      // Trade via 1inch
      receivedAmount = _tradeViaOneInchMock(_source, _destination, _sourceAmount, _additionalData);
    }
    else {
      // unknown exchange type
      revert();
    }

    // transfer asset B back to sender
    if (_destination == ETH_TOKEN_ADDRESS) {
      (msg.sender).transfer(receivedAmount);
    } else {
      // transfer tokens received to sender
      _destination.transfer(msg.sender, receivedAmount);
    }


    emit Trade(msg.sender, address(_source), _sourceAmount, address(_destination), receivedAmount, uint8(_type));

    return receivedAmount;
  }

  // Mock for trade via Bancor, Paraswap, OneInch
  // This DEXs has the same logic
  // Transfer asset A from fund and send asset B back to fund
  function _trade(IERC20 _source, IERC20 _destination, uint256 _sourceAmount)
   private
   returns(uint256 receivedAmount)
  {
    // we can broke transfer for tests
    if(!stopTransfer){
      // transfer asset A from sender
      if (_source == ETH_TOKEN_ADDRESS) {
        receivedAmount = getValue(address(_source), address(_destination), _sourceAmount);
      } else {
        _transferFromSenderAndApproveTo(_source, _sourceAmount, NULL_ADDRESS);
        receivedAmount = getValue(address(_source), address(_destination), _sourceAmount);
      }
    }else{
      receivedAmount = 0;
    }
  }

  function _tradeViaOneInchMock(
    IERC20 _source,
    IERC20 _destination,
    uint256 _sourceAmount,
    bytes calldata _additionalData
  )
    private
    returns(uint256)
  {
    // test decode params
    (uint256 flags,
     uint256[] memory _distribution) = abi.decode(_additionalData, (uint256, uint256[]));

    // check params
    require(flags > 0, "Not correct flags param for 1inch aggregator");
    require(_distribution.length > 0, "Not correct _distribution param for 1inch aggregator");

    return _trade(_source, _destination, _sourceAmount);
  }


  function _tradeViaParaswapMock(
    IERC20 _source,
    IERC20 _destination,
    uint256 _sourceAmount,
    bytes calldata _additionalData
  )
    private
    returns(uint256)
  {
    // Test decode correct params
    (uint256 minDestinationAmount,
     address[] memory callees,
     uint256[] memory startIndexes,
     uint256[] memory values,
     uint256 mintPrice,
     bytes memory exchangeData) = abi.decode(
       _additionalData,
       (uint256, address[], uint256[], uint256[], uint256, bytes)
     );

     // check params
     require(minDestinationAmount > 0, 'Not corerct minDestinationAmount param for Paraswap');
     require(callees.length > 0, 'Not corerct callees param for Paraswap');
     require(startIndexes.length  > 0, 'Not corerct startIndexes param for Paraswap');
     require(values.length  > 0, 'Not corerct values param for Paraswap');
     require(mintPrice > 0, 'Not corerct mintPrice param for Paraswap');

     return _trade(_source, _destination, _sourceAmount);
  }

  // Facilitates for verify destanation token input (check if token in merkle list or not)
  // revert transaction if token not in list
  function _verifyToken(
    address _destination,
    bytes32 [] memory proof,
    uint256 [] memory positions)
    private
  {
    bool status = merkleTreeWhiteList.verify(_destination, proof, positions);

    if(!status)
      revert("Dest not in white list");
  }


  // Possibilities:
  // * kyber.getExpectedRate
  // * kyber.findBestRate
  function getValue(address _from, address _to, uint256 _amount) public view returns (uint256) {
    // ETH case (can change rate)
    if (_to == address(ETH_TOKEN_ADDRESS)) {
      return _amount.mul(div).div(mul);
    }
    else if (_from == address(ETH_TOKEN_ADDRESS)) {
      return _amount.mul(mul).div(div);
    }
    // DAI Case (can change rate)
    else if(_to == stableCoinAddress) {
      return _amount.mul(div).div(mul);
    }
    else if(_from == stableCoinAddress) {
      return _amount.mul(mul).div(div);
    }
    // ERC case
    else {
      return _amount;
    }
  }

  // get the total value of multiple tokens and amounts in one go
  function getTotalValue(address[] memory _fromAddresses, uint256[] memory _amounts, address _to) public view returns (uint256) {
    uint256 sum = 0;

    for (uint256 i = 0; i < _fromAddresses.length; i++) {
      sum = sum.add(getValue(_fromAddresses[i], _to, _amounts[i]));
    }

    return sum;
  }

  function setRatio(uint256 _mul, uint256 _div) public {
    mul = _mul;
    div = _div;
  }


  function _transferFromSenderAndApproveTo(IERC20 _source, uint256 _sourceAmount, address _to) private {
    require(_source.transferFrom(msg.sender, address(this), _sourceAmount));
    // reset previos approve because some tokens require allowance 0
    _source.approve(_to, 0);
    // approve
    _source.approve(_to, _sourceAmount);
  }

  function changeStopTransferStatus(bool _status) public {
    stopTransfer = _status;
  }

  function pay() public payable {}

  fallback() external payable {}
}
