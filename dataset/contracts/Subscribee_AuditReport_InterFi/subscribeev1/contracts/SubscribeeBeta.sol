// SPDX-License-Identifier: Business Source License 1.1
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SubscribeeBeta is Ownable, ReentrancyGuard{

  uint8 public nextPlanId;
  string public title;
  string public image;

  mapping(uint8 => address[]) private subscriberLists;
  mapping(uint8 => Plan) public plans;
  mapping(uint8 => mapping(address => Subscription)) public subscriptions;

  address public operator;

  // Structs

  struct Plan {
    string title;
    address token;
    uint128 amount;
    uint32 frequency;
    bool halted;
  }

  struct Subscription {
    uint256 start;
    uint256 nextPayment;
    bool stopped;
    uint256 userId;
  }

  struct UserObject {
    address subscriber;
    uint8 planId;
  }


  // Events


  event PlanCreated(
    string title,
    address token,
    uint128 amount,
    uint128 frequency
  );

  event SubscriptionCreated(
    address subscriber,
    uint8 planId,
    uint256 date
  );

  event SubscriptionDeleted(
    address subscriber,
    uint8 planId,
    uint256 date,
    string reason
  );

  event PaymentSent(
    address from,
    uint128 amount,
    uint8 planId,
    uint256 date
  );

  // Modifiers

  modifier onlyOperatorOrOwner() {
    require(msg.sender == operator || msg.sender == owner(), 'Huh?');
    _;
  }

  // Constructor

  constructor(address operatorAddress, string memory newTitle, string memory newImage) {
    operator = operatorAddress;
    title = newTitle;
    image = newImage;
  }


  // External Functions

  function subscribe(uint8 planId) external {
    _safeSubscribe(planId);
  }

  function stopPay(uint8 planId) external {
    _stop(planId);
  }

  function selfDelete(uint8 planId) external {
    _delete(msg.sender, planId, 'User Deleting Subscription');
  }

  function selfPay(uint8 planId) external {
    _safePay(msg.sender, planId);
  }

  function setOperator(address newOperator) external onlyOwner{
    operator = newOperator;
  }

  function setTitle(string memory newTitle) external onlyOwner{
    title = newTitle;
  }

  function setImage(string memory newImage) external onlyOwner{
    image = newImage;
  }

  function togglePlanHalt(uint8 planId) external onlyOwner{
    if(plans[planId].halted){
      plans[planId].halted = false;
    }else{
      plans[planId].halted = true;
    }
  }

  function createPlan(string memory planTitle, address token, uint128 amount, uint32 frequency) external onlyOwner{
    require(token != address(0), 'address cannot be null address');
    require(amount > 0, 'amount needs to be > 0');
    require(frequency >= 86400, 'frequency needs to be greater or equal to 24 hours');

    plans[nextPlanId] = Plan(
      planTitle,
      token,
      amount,
      frequency,
      false
    );

    emit PlanCreated(title, token, amount, frequency);
    nextPlanId++;
  }

  function getSubscriberArray(uint8 planId) external view onlyOperatorOrOwner returns(address[] memory){
    return subscriberLists[planId];
  }

  function multiPay(UserObject[] memory users) external onlyOperatorOrOwner nonReentrant{
    for(uint i = 0; i < users.length; i++){
      address subscriber = users[i].subscriber;
      uint8 planId = users[i].planId;
      _safePay(subscriber, planId);
    }
  }

  function multiDelete(UserObject[] memory users) external onlyOperatorOrOwner{
    for(uint i = 0; i < users.length; i++){
      address subscriber = users[i].subscriber;
      uint8 planId = users[i].planId;
      _delete(subscriber, planId, 'Owner/Operator Deleted Subscription');
    }
  }

  // Private Functions

  function _safePay(address subscriber, uint8 planId) private {
    // call from storage
    Subscription storage subscription = subscriptions[planId][subscriber];
    Plan storage plan = plans[planId];
    IERC20 token = IERC20(plan.token);

    // conditionals
    require(
       subscription.start != 0,
      'this subscription does not exist'
    );

    require(
      block.timestamp > subscription.nextPayment,
      'not due yet'
    );

    require(
      !plan.halted,
      'Plan is halted'
    );

    require(
      !subscription.stopped,
      'Subscriber opted to stop payments; delete subscription'
    );

    require(
      token.balanceOf(subscriber) >= plan.amount,
      'Subscriber has insufficent funds; delete subscription'
    );

    // send to Contract Owner
    require(token.transferFrom(subscriber, owner(), plan.amount));

    // set next payment
    subscription.nextPayment = subscription.nextPayment + plan.frequency;

    // emit event
      emit PaymentSent(
        subscriber,
        plan.amount,
        planId,
        block.timestamp
      );
    }

  function _safeSubscribe(uint8 planId) private {
    // calls plan from storage and check if it exists
    Plan storage plan = plans[planId];
    require(plan.token != address(0), 'this plan does not exist');
    require(!plan.halted, 'plan is halted');

    // set token and fee
    IERC20 token = IERC20(plan.token);

    // send to Contract Owner
    require(token.transferFrom(msg.sender, owner(), plan.amount));

    subscriberLists[planId].push(msg.sender);

    // add new subscription
    subscriptions[planId][msg.sender] = Subscription(
      block.timestamp,
      block.timestamp + plan.frequency,
      false,
      subscriberLists[planId].length - 1
    );

    // emit Subscription and Payment events
    emit SubscriptionCreated(
      msg.sender,
      planId,
      block.timestamp
    );

    emit PaymentSent(
      msg.sender,
      plan.amount,
      planId,
      block.timestamp
    );

  }

  function _delete(address user, uint8 planId, string memory reason) private {
    // Grab user subscription data & check if it exists
    Subscription storage subscription = subscriptions[planId][user];
    require(subscription.start != 0, 'this subscription does not exist');

    // delete from array
    address[] storage subscriberArray = subscriberLists[planId];
    uint256 userID = subscription.userId;
    address addressToChange = subscriberArray[subscriberArray.length - 1];
    subscriberArray[userID] = addressToChange;
    subscriptions[planId][addressToChange].userId = userID;
    subscriberArray.pop();

    // delete from mapping
    delete subscriptions[planId][user];

    emit SubscriptionDeleted(user, planId, block.timestamp, reason);
  }

  function _stop(uint8 planId) private {
    // Grab user subscription data & check if it exists
    Subscription storage subscription = subscriptions[planId][msg.sender];
    require(subscription.start != 0, 'this subscription does not exist');

    // Check if user owes funds and is trying to stop, will delete
    if(subscription.nextPayment < block.timestamp){
      _delete(msg.sender, planId, 'You cannot stop subscription after funds are owed, subscription deleted');
      return;
    }

    // If user does not have to pay yet, stop subscription
    subscription.stopped = true;
  }
}
