// This contract need only for tests!!!
// This contract Mock 1 inch aggregator with Bancor network

pragma solidity ^0.6.12;


import "../contracts/zeppelin-solidity/contracts/access/Ownable.sol";
import "../contracts/zeppelin-solidity/contracts/math/SafeMath.sol";

import "../contracts/bancor/interfaces/IGetBancorData.sol";
import "../contracts/bancor/interfaces/BancorNetworkInterface.sol";

import "../contracts/oneInch/IOneSplitAudit.sol";

import "../contracts/core/interfaces/ExchangePortalInterface.sol";
import "../contracts/core/interfaces/DefiPortalInterface.sol";
import "../contracts/core/interfaces/PoolPortalViewInterface.sol";
import "../contracts/core/interfaces/IMerkleTreeTokensVerification.sol";


contract ExchangePortal is ExchangePortalInterface, Ownable {
  using SafeMath for uint256;

  uint public version = 4;

  // Contract for merkle tree white list verification
  IMerkleTreeTokensVerification public merkleTreeWhiteList;

  // 1INCH
  IOneSplitAudit public oneInch;

  // BANCOR
  IGetBancorData public bancorData;

  // CoTrader portals
  PoolPortalViewInterface public poolPortal;
  DefiPortalInterface public defiPortal;

  // 1 inch flags
  // By default support Bancor + Uniswap + Uniswap v2
  uint256 oneInchFlags = 570425349;

  // Enum
  // NOTE: You can add a new type at the end, but DO NOT CHANGE this order,
  // because order has dependency in other contracts like ConvertPortal
  enum ExchangeType { Paraswap, Bancor, OneInch }

  // This contract recognizes ETH by this address
  IERC20 constant private ETH_TOKEN_ADDRESS = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

  // Trade event
  event Trade(
     address trader,
     address src,
     uint256 srcAmount,
     address dest,
     uint256 destReceived,
     uint8 exchangeType
  );

  // black list for non trade able tokens
  mapping (address => bool) disabledTokens;

  // Modifier to check that trading this token is not disabled
  modifier tokenEnabled(IERC20 _token) {
    require(!disabledTokens[address(_token)]);
    _;
  }

  /**
  * @dev contructor
  *
  * @param _defiPortal             address of defiPortal contract
  * @param _bancorData             address of GetBancorData helper
  * @param _poolPortal             address of pool portal
  * @param _oneInch                address of 1inch OneSplitAudit contract
  * @param _merkleTreeWhiteList    address of the IMerkleTreeWhiteList
  */
  constructor(
    address _defiPortal,
    address _bancorData,
    address _poolPortal,
    address _oneInch,
    address _merkleTreeWhiteList
    )
    public
  {
    defiPortal = DefiPortalInterface(_defiPortal);
    bancorData = IGetBancorData(_bancorData);
    poolPortal = PoolPortalViewInterface(_poolPortal);
    oneInch = IOneSplitAudit(_oneInch);
    merkleTreeWhiteList = IMerkleTreeTokensVerification(_merkleTreeWhiteList);
  }


  // EXCHANGE Functions

  /**
  * @dev Facilitates a trade for a SmartFund
  *
  * @param _source            ERC20 token to convert from
  * @param _sourceAmount      Amount to convert from (in _source token)
  * @param _destination       ERC20 token to convert to
  * @param _type              The type of exchange to trade with
  * @param _proof             Merkle tree proof (if not used just set [])
  * @param _positions         Merkle tree positions (if not used just set [])
  * @param _additionalData    For additional data (if not used just set 0x0)
  * @param _verifyDestanation For additional check if token in list or not
  *
  * @return receivedAmount    The amount of _destination received from the trade
  */
  function trade(
    IERC20 _source,
    uint256 _sourceAmount,
    IERC20 _destination,
    uint256 _type,
    bytes32[] calldata _proof,
    uint256[] calldata _positions,
    bytes calldata _additionalData,
    bool _verifyDestanation
  )
    external
    override
    payable
    tokenEnabled(_destination)
    returns (uint256 receivedAmount)
  {
    // throw if destanation token not in white list
    if(_verifyDestanation)
      _verifyToken(address(_destination), _proof, _positions);

    require(_source != _destination, "source can not be destination");

    // check ETH payable case
    if (_source == ETH_TOKEN_ADDRESS) {
      require(msg.value == _sourceAmount);
    } else {
      require(msg.value == 0);
    }

    // SHOULD TRADE PARASWAP HERE
    if (_type == uint(ExchangeType.Paraswap)) {
      revert("PARASWAP not supported");
    }
    // SHOULD TRADE BANCOR HERE
    else if (_type == uint(ExchangeType.Bancor)){
      receivedAmount = _tradeViaBancorNewtork(
          address(_source),
          address(_destination),
          _sourceAmount
      );
    }
    // SHOULD TRADE 1INCH HERE
    else if (_type == uint(ExchangeType.OneInch)){
      // throw if addition 1inch data not correct
      _verifyOneInchData(_additionalData);
      // mock with Bancor
      receivedAmount = _tradeViaBancorNewtork(
          address(_source),
          address(_destination),
          _sourceAmount
      );
    }

    else {
      // unknown exchange type
      revert();
    }

    // Additional check
    require(receivedAmount > 0, "received amount can not be zerro");

    // Send destination
    if (_destination == ETH_TOKEN_ADDRESS) {
      (msg.sender).transfer(receivedAmount);
    } else {
      // transfer tokens received to sender
      _destination.transfer(msg.sender, receivedAmount);
    }

    // Send remains
    _sendRemains(_source, msg.sender);

    // Trigger event
    emit Trade(
      msg.sender,
      address(_source),
      _sourceAmount,
      address(_destination),
      receivedAmount,
      uint8(_type)
    );
  }

  // Facilitates for send source remains
  function _sendRemains(IERC20 _source, address _receiver) private {
    // After the trade, any _source that exchangePortal holds will be sent back to msg.sender
    uint256 endAmount = (_source == ETH_TOKEN_ADDRESS)
    ? address(this).balance
    : _source.balanceOf(address(this));

    // Check if we hold a positive amount of _source
    if (endAmount > 0) {
      if (_source == ETH_TOKEN_ADDRESS) {
        payable(_receiver).transfer(endAmount);
      } else {
        _source.transfer(_receiver, endAmount);
      }
    }
  }


  // Facilitates for verify destanation token input (check if token in merkle list or not)
  // revert transaction if token not in list
  function _verifyToken(
    address _destination,
    bytes32 [] memory proof,
    uint256 [] memory positions)
    private
    view
  {
    bool status = merkleTreeWhiteList.verify(_destination, proof, positions);

    if(!status)
      revert("Dest not in white list");
  }


 // Facilitates trade with Bancor
 function _tradeViaBancorNewtork(
   address sourceToken,
   address destinationToken,
   uint256 sourceAmount
   )
   private
   returns(uint256 returnAmount)
 {
    // get latest bancor contracts
    BancorNetworkInterface bancorNetwork = BancorNetworkInterface(
      bancorData.getBancorContractAddresByName("BancorNetwork")
    );

    // Get Bancor tokens path
    address[] memory path = bancorData.getBancorPathForAssets(IERC20(sourceToken), IERC20(destinationToken));

    // Convert addresses to ERC20
    IERC20[] memory pathInERC20 = new IERC20[](path.length);
    for(uint i=0; i<path.length; i++){
        pathInERC20[i] = IERC20(path[i]);
    }

    // trade
    if (IERC20(sourceToken) == ETH_TOKEN_ADDRESS) {
      returnAmount = bancorNetwork.convert.value(sourceAmount)(pathInERC20, sourceAmount, 1);
    }
    else {
      _transferFromSenderAndApproveTo(IERC20(sourceToken), sourceAmount, address(bancorNetwork));
      returnAmount = bancorNetwork.claimAndConvert(pathInERC20, sourceAmount, 1);
    }
 }

  // for test correct decode
  function _verifyOneInchData(
    bytes memory _additionalData
    )
    private
  {
     (uint256 flags,
      uint256[] memory _distribution) = abi.decode(_additionalData, (uint256, uint256[]));

      // check params
      require(flags > 0, "Not correct flags param for 1inch aggregator");
  }


  /**
  * @dev Transfers tokens to this contract and approves them to another address
  *
  * @param _source          Token to transfer and approve
  * @param _sourceAmount    The amount to transfer and approve (in _source token)
  * @param _to              Address to approve to
  */
  function _transferFromSenderAndApproveTo(IERC20 _source, uint256 _sourceAmount, address _to) private {
    require(_source.transferFrom(msg.sender, address(this), _sourceAmount));
    // reset previos approve because some tokens require allowance 0
    _source.approve(_to, 0);
    // approve
    _source.approve(_to, _sourceAmount);
  }



  // VIEW Functions

  function tokenBalance(IERC20 _token) private view returns (uint256) {
    if (_token == ETH_TOKEN_ADDRESS)
      return address(this).balance;
    return _token.balanceOf(address(this));
  }

  /**
  * @dev Gets the ratio by amount of token _from in token _to by totekn type
  *
  * @param _from      Address of token we're converting from
  * @param _to        Address of token we're getting the value in
  * @param _amount    The amount of _from
  *
  * @return best price from 1inch for ERC20, or ratio for Uniswap and Bancor pools
  */
  function getValue(address _from, address _to, uint256 _amount)
    public
    override
    view
    returns (uint256)
  {
    if(_amount > 0)
      return getValueViaDEXsAgregators(_from, _to, _amount);
  }

  /**
  * @dev find the ratio by amount of token _from in token _to trying all available methods
  *
  * @param _from      Address of token we're converting from
  * @param _to        Address of token we're getting the value in
  * @param _amount    The amount of _from
  *
  * @return best price from 1inch for ERC20, or ratio for Uniswap and Bancor pools
  */
  function findValue(address _from, address _to, uint256 _amount) private view returns (uint256) {
     if(_amount > 0){
       // Check at first value from defi portal, maybe there are new defi protocols
       // If defiValue return 0 continue check from another sources
       uint256 defiValue = defiPortal.getValue(_from, _to, _amount);
       if(defiValue > 0)
          return defiValue;

       // If 1inch return 0, check from Bancor network for ensure this is not a Bancor pool
       uint256 oneInchResult = getValueViaDEXsAgregators(_from, _to, _amount);
       if(oneInchResult > 0)
         return oneInchResult;

       // If Bancor return 0, check from Balancer network for ensure this is not Balancer asset
       uint256 bancorResult = getValueViaBancor(_from, _to, _amount);
       if(bancorResult > 0)
          return bancorResult;

       // If Balancer return 0, check from Uniswap pools for ensure this is not Uniswap pool
       uint256 balancerResult = getValueForBalancerPool(_from, _to, _amount);
       if(balancerResult > 0)
          return balancerResult;

       // If Uniswap return 0, check from Uniswap version 2 pools for ensure this is not Uniswap V2 pool
       uint256 uniswapResult = getValueForUniswapPools(_from, _to, _amount);
       if(uniswapResult > 0)
          return uniswapResult;

       // Uniswap V2 pools return 0 if these is not a Uniswap V2 pool
       return getValueForUniswapV2Pools(_from, _to, _amount);
     }
     else{
       return 0;
     }
  }


  // helper for get value via 1inch
  // in this interface can be added more DEXs aggregators
  function getValueViaDEXsAgregators(
    address _from,
    address _to,
    uint256 _amount
  )
  public view returns (uint256){
    // if direction the same, just return amount
    if(_from == _to)
       return _amount;

    // try get value via 1inch
    if(_amount > 0){
      // Mock 1 inch with Bancor
      return getValueViaBancor(_from, _to, _amount);
    }
    else{
      return 0;
    }
  }



  // helper for get ratio between assets in Bancor network
  function getValueViaBancor(
    address _from,
    address _to,
    uint256 _amount
  )
    public
    view
    returns (uint256 value)
  {
    // if direction the same, just return amount
    if(_from == _to)
       return _amount;

    // try get rate
    if(_amount > 0){
      try poolPortal.getBancorRatio(_from, _to, _amount) returns(uint256 result){
        value = result;
      }catch{
        value = 0;
      }
    }else{
      return 0;
    }
  }


  // helper for get value via Balancer
  function getValueForBalancerPool(
    address _from,
    address _to,
    uint256 _amount
  )
    public
    view
    returns (uint256 value)
  {
    // get value for each pool share
    try poolPortal.getBalancerConnectorsAmountByPoolAmount(_amount, _from)
    returns(
      address[] memory tokens,
      uint256[] memory tokensAmount
    )
    {
     // convert and sum value via DEX aggregator
     for(uint i = 0; i < tokens.length; i++){
       value += getValueViaDEXsAgregators(tokens[i], _to, tokensAmount[i]);
     }
    }
    catch{
      value = 0;
    }
  }

  // helper for get ratio between pools in Uniswap network
  // _from - should be uniswap pool address
  function getValueForUniswapPools(
    address _from,
    address _to,
    uint256 _amount
  )
  public
  view
  returns (uint256)
  {
    // get connectors amount
    try poolPortal.getUniswapConnectorsAmountByPoolAmount(
      _amount,
      _from
    ) returns (uint256 ethAmount, uint256 ercAmount)
    {
      // get ERC amount in ETH
      address token = poolPortal.getTokenByUniswapExchange(_from);
      uint256 ercAmountInETH = getValueViaDEXsAgregators(token, address(ETH_TOKEN_ADDRESS), ercAmount);
      // sum ETH with ERC amount in ETH
      uint256 totalETH = ethAmount.add(ercAmountInETH);

      // if _to == ETH no need additional convert, just return ETH amount
      if(_to == address(ETH_TOKEN_ADDRESS)){
        return totalETH;
      }
      // convert ETH into _to asset via 1inch
      else{
        return getValueViaDEXsAgregators(address(ETH_TOKEN_ADDRESS), _to, totalETH);
      }
    }catch{
      return 0;
    }
  }


  // helper for get ratio between pools in Uniswap network version 2
  // _from - should be uniswap pool address
  function getValueForUniswapV2Pools(
    address _from,
    address _to,
    uint256 _amount
  )
  public
  view
  returns (uint256)
  {
    // get connectors amount by pool share
    try poolPortal.getUniswapV2ConnectorsAmountByPoolAmount(
      _amount,
      _from
    ) returns (
      uint256 tokenAmountOne,
      uint256 tokenAmountTwo,
      address tokenAddressOne,
      address tokenAddressTwo
      )
    {
      // convert connectors amount via DEX aggregator
      uint256 amountOne = getValueViaDEXsAgregators(tokenAddressOne, _to, tokenAmountOne);
      uint256 amountTwo = getValueViaDEXsAgregators(tokenAddressTwo, _to, tokenAmountTwo);
      // return value
      return amountOne + amountTwo;
    }catch{
      return 0;
    }
  }

  /**
  * @dev Gets the total value of array of tokens and amounts
  *
  * @param _fromAddresses    Addresses of all the tokens we're converting from
  * @param _amounts          The amounts of all the tokens
  * @param _to               The token who's value we're converting to
  *
  * @return The total value of _fromAddresses and _amounts in terms of _to
  */
  function getTotalValue(
    address[] calldata _fromAddresses,
    uint256[] calldata _amounts,
    address _to)
    external
    override
    view
    returns (uint256)
  {
    uint256 sum = 0;
    for (uint256 i = 0; i < _fromAddresses.length; i++) {
      sum = sum.add(getValue(_fromAddresses[i], _to, _amounts[i]));
    }
    return sum;
  }

  // SETTERS Functions

  /**
  * @dev Allows the owner to disable/enable the buying of a token
  *
  * @param _token      Token address whos trading permission is to be set
  * @param _enabled    New token permission
  */
  function setToken(address _token, bool _enabled) external onlyOwner {
    disabledTokens[_token] = _enabled;
  }

  // owner can change oneInch
  function setNewOneInch(address _oneInch) external onlyOwner {
    oneInch = IOneSplitAudit(_oneInch);
  }

  // owner can set new pool portal
  function setNewPoolPortal(address _poolPortal) external onlyOwner {
    poolPortal = PoolPortalViewInterface(_poolPortal);
  }

  // owner can set new defi portal
  function setNewDefiPortal(address _defiPortal) external onlyOwner {
    defiPortal = DefiPortalInterface(_defiPortal);
  }

  // owner of portal can update 1 incg DEXs sources
  function setOneInchFlags(uint256 _oneInchFlags) external onlyOwner {
    oneInchFlags = _oneInchFlags;
  }

  // owner of portal can change getBancorData helper, for case if Bancor do some major updates
  function setNewGetBancorData(address _bancorData) external onlyOwner {
    bancorData = IGetBancorData(_bancorData);
  }

  // fallback payable function to receive ether from other contract addresses
  fallback() external payable {}

}
