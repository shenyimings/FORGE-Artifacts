pragma solidity ^0.4.21;

import "./zeppelin-solidity/contracts/math/SafeMath.sol";
import "./zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "./zeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract ICOStartSaleInterface {
  ERC20 public token;
}

contract ICOStartReservation is Pausable {
  using SafeMath for uint256;

  ICOStartSaleInterface public sale;
  uint256 public cap;
  uint8 public feePerc;
  address public manager;
  mapping(address => uint256) public deposits;
  uint256 public weiCollected;
  uint256 public tokensReceived;
  bool public canceled;
  bool public paid;

  event Deposited(address indexed depositor, uint256 amount);
  event Withdrawn(address indexed beneficiary, uint256 amount);
  event Paid(uint256 netAmount, uint256 fee);
  event Canceled();

  function ICOStartReservation(ICOStartSaleInterface _sale, uint256 _cap, uint8 _feePerc, address _manager) public {
    require(_sale != (address(0)));
    require(_cap != 0);
    require(_feePerc >= 0);

    sale = _sale;
    cap = _cap;
    feePerc = _feePerc;
    manager = _manager;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is accepting
   * deposits.
   */
  modifier whenOpen() {
    require(isOpen());
    _;
  }

  /**
   * @dev Modifier to make a function callable only if the reservation was not canceled.
   */
  modifier whenNotCanceled() {
    require(!canceled);
    _;
  }

  /**
   * @dev Modifier to make a function callable only if the reservation was canceled.
   */
  modifier whenCanceled() {
    require(canceled);
    _;
  }

  /**
   * @dev Modifier to make a function callable only if the reservation was not yet paid.
   */
  modifier whenNotPaid() {
    require(!paid);
    _;
  }

  /**
   * @dev Modifier to make a function callable only if the reservation was paid.
   */
  modifier whenPaid() {
    require(paid);
    _;
  }

  /**
   * @dev Checks whether the cap has been reached. 
   * @return Whether the cap was reached
   */
  function capReached() public view returns (bool) {
    return weiCollected >= cap;
  }

  /**
   * @dev Checks whether the cap has been reached. 
   * @return Whether the cap was reached
   */
  function getToken() public view returns (ERC20) {
    return sale.token();
  }

  /**
   * @dev Modifier to make a function callable only when the contract is accepting
   * deposits.
   */
  function isOpen() public view returns (bool) {
    return !paused && !capReached() && !canceled && !paid;
  }

  /**
   * @dev Shortcut for deposit() and claimTokens() functions.
   * Send 0 to claim, any other value to deposit.
   */
  function () external payable {
    if (msg.value == 0) {
      claimTokens(msg.sender);
    } else {
      deposit(msg.sender);
    }
  }

  /**
   * @dev Deposit ethers in the contract keeping track of the sender.
   * @param _depositor Address performing the purchase
   */
  function deposit(address _depositor) public whenOpen payable {
    require(_depositor != address(0));
    require(weiCollected.add(msg.value) <= cap);
    deposits[_depositor] = deposits[_depositor].add(msg.value);
    weiCollected = weiCollected.add(msg.value);
    emit Deposited(_depositor, msg.value);
  }

  /**
   * @dev Allows the owner to cancel the reservation thus enabling withdraws.
   * Contract must first be paused so we are sure we are not accepting deposits.
   */
  function cancel() public onlyOwner whenPaused whenNotPaid {
    canceled = true;
  }

  /**
   * @dev Allows the owner to cancel the reservation thus enabling withdraws.
   * Contract must first be paused so we are sure we are not accepting deposits.
   */
  function pay() public onlyOwner whenNotCanceled {
    require(weiCollected > 0);
  
    uint256 fee;
    uint256 netAmount;
    (fee, netAmount) = _getFeeAndNetAmount(weiCollected);

    require(address(sale).call.value(netAmount)(this));
    tokensReceived = getToken().balanceOf(this);

    if (fee != 0) {
      manager.transfer(fee);
    }

    paid = true;
    emit Paid(netAmount, fee);
  }

  /**
   * @dev Allows a depositor to withdraw his contribution if the reservation was canceled.
   */
  function withdraw() public whenCanceled {
    uint256 depositAmount = deposits[msg.sender];
    require(depositAmount != 0);
    deposits[msg.sender] = 0;
    weiCollected = weiCollected.sub(depositAmount);
    msg.sender.transfer(depositAmount);
    emit Withdrawn(msg.sender, depositAmount);
  }

  /**
   * @dev After the reservation is paid, transfers tokens from the contract to the
   * specified address (which must have deposited ethers earlier).
   * @param _beneficiary Address that will receive the tokens.
   */
  function claimTokens(address _beneficiary) public whenPaid {
    require(_beneficiary != address(0));
    
    uint256 depositAmount = deposits[_beneficiary];
    if (depositAmount != 0) {
      uint256 tokens = tokensReceived.mul(depositAmount).div(weiCollected);
      assert(tokens != 0);
      deposits[_beneficiary] = 0;
      getToken().transfer(_beneficiary, tokens);
    }
  }

  /**
   * @dev Emergency brake. Send all ethers and tokens to the owner.
   */
  function destroy() onlyOwner public {
    uint256 myTokens = getToken().balanceOf(this);
    if (myTokens != 0) {
      getToken().transfer(owner, myTokens);
    }
    selfdestruct(owner);
  }

  /*
   * Internal functions
   */

  /**
   * @dev Returns the current period, or null.
   */
   function _getFeeAndNetAmount(uint256 _grossAmount) internal view returns (uint256 _fee, uint256 _netAmount) {
      _fee = _grossAmount.div(100).mul(feePerc);
      _netAmount = _grossAmount.sub(_fee);
   }
}