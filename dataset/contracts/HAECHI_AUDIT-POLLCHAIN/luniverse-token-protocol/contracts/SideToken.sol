pragma solidity ^0.4.24;

import "./ERC20Token.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./SideBridge.sol";

contract SideToken is ERC20Token, Ownable {
  using SafeMath for uint256;

  address public sideBridgeAddress;
  bytes32 sideTokenId;

  event Minted(address beneficiary, uint256 amount);
  event TransferredWithFee(address to, uint256 amount, address feeCollector, uint256 fee);

  constructor(string _name, string _symbol, uint8 _decimals, address _sideBridge)
    ERC20Token(_name, _symbol, _decimals, 0, 0)
  public
  {
    require(_sideBridge != address(0));

    sideBridgeAddress = _sideBridge;
  }

  function setSideTokenId(bytes32 _sideTokenId) external {
    require( msg.sender == sideBridgeAddress);

    sideTokenId = _sideTokenId;
  }

  function mint(address _beneficiary, uint256 _amount) external {
    require(sideTokenId != 0 );

    require(msg.sender == sideBridgeAddress);

    totalSupply = totalSupply.add(_amount);
    _balances[_beneficiary] = _balances[_beneficiary].add(_amount);

    emit Minted(_beneficiary, _amount);
  }

  function transferWithFee(address _to, uint256 _amount, address _feeCollector, uint256 _fee)
  external {
    require(sideTokenId != 0 );

    transfer(_to, _amount);
    transfer(_feeCollector, _fee);

    emit TransferredWithFee(_to, _amount, _feeCollector, _fee);
  }

  function stake(uint256 _amount) external {
    require(sideTokenId != 0 );

    SideBridge sideBridge = SideBridge(sideBridgeAddress);

    super.approve(sideBridgeAddress, _amount);

    sideBridge.stake(sideTokenId, msg.sender, _amount);
  }

  function unstake(uint256 _amount) external {
    require(sideTokenId != 0 );

    SideBridge sideBridge = SideBridge(sideBridgeAddress);

    sideBridge.unstake(sideTokenId, msg.sender, _amount);
  }

  function vest(uint256 _amount, uint256 _cliff, uint256 _duration, uint256 _interval) external {
    require(sideTokenId != 0 );

    SideBridge sideBridge = SideBridge(sideBridgeAddress);

    super.approve(sideBridgeAddress, _amount);

    sideBridge.vest(sideTokenId, msg.sender, _amount, _cliff, _duration, _interval);
  }

  function redeem(uint256 _amount) external {
    require(sideTokenId != 0 );

    SideBridge sideBridge = SideBridge(sideBridgeAddress);

    super.approve(sideBridgeAddress, _amount);

    sideBridge.redeem(sideTokenId, msg.sender, _amount);
  }

  function burn(uint256 _amount) external {
    require(msg.sender == sideBridgeAddress);

    // burn owning token and decrease total supply\
    _balances[address(this)] = _balances[address(this)].sub(_amount);

    totalSupply = totalSupply.sub(_amount);
  }
}
