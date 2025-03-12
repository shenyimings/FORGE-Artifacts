pragma solidity ^0.5.16;

import "./WBep20Delegate.sol";

interface WelLike {
  function delegate(address delegatee) external;
}

/**
 * @title Welnance's WWelLikeDelegate Contract
 * @notice WLTokens which can 'delegate votes' of their underlying BEP-20
 * @author Welnance
 */
contract WelLikeDelegate is WBep20Delegate {
  /**
   * @notice Construct an empty delegate
   */
  constructor() public WBep20Delegate() {}

  /**
   * @notice Admin call to delegate the votes of the WELNANCE-like underlying
   * @param welLikeDelegatee The address to delegate votes to
   */
  function _delegateWelLikeTo(address welLikeDelegatee) external {
    require(msg.sender == admin, "only the admin may set the wel-like delegate");
    WelLike(underlying).delegate(welLikeDelegatee);
  }
}