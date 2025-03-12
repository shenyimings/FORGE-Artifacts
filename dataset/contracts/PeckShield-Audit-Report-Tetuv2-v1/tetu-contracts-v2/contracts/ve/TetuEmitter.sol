// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../proxy/ControllableV3.sol";
import "../openzeppelin/SafeERC20.sol";
import "../interfaces/IVeDistributor.sol";
import "../interfaces/IVoter.sol";
import "../interfaces/IBribe.sol";

contract TetuEmitter is ControllableV3 {
  using SafeERC20 for IERC20;

  // *************************************************************
  //                        CONSTANTS
  // *************************************************************

  /// @dev Version of this contract. Adjust manually on each code modification.
  string public constant EMITTER_VERSION = "1.0.0";
  /// @dev Epoch period delay
  uint public constant EPOCH_LENGTH = 7 days;
  /// @dev Denominator for different ratios. It is default for the whole platform.
  uint public constant RATIO_DENOMINATOR = 100_000;

  // *************************************************************
  //                        VARIABLES
  //                Keep names and ordering!
  //                 Add only in the bottom.
  // *************************************************************

  /// @dev Token for distribution
  address public token;
  /// @dev Caller of start epoch
  address public operator;
  /// @dev Current epoch, for statistic purposes
  uint public epoch;
  /// @dev Timestamp when the current epoch was started
  uint public startEpochTS;
  /// @dev Minimal amount of token for start epoch. Preventing human mistakes and duplicate calls.
  uint public minAmountPerEpoch;
  /// @dev How much amount will be send to VeDistributor. Change will be used to gauge rewards.
  uint public toVeRatio;
  /// @dev Bribe address for trigger new epoch start.
  address public bribe;

  // *************************************************************
  //                        EVENTS
  // *************************************************************

  event EpochStarted(uint epoch, uint startEpochTS, uint balance, uint toVe, uint toVoter);
  event OperatorChanged(address operator);
  event MinAmountPerEpochChanged(uint value);
  event ToVeRatioChanged(uint value);

  // *************************************************************
  //                        INIT
  // *************************************************************

  function init(address _controller, address _token, address _bribe) external initializer {
    __Controllable_init(_controller);
    _requireERC20(_token);
    _requireInterface(_bribe, InterfaceIds.I_BRIBE);

    operator = msg.sender;
    token = _token;
    bribe = _bribe;
    emit OperatorChanged(msg.sender);
  }

  // *************************************************************
  //                      RESTRICTIONS
  // *************************************************************

  function _onlyOperator() internal view {
    require(operator == msg.sender, "!operator");
  }

  function _olyGov() internal view {
    require(isGovernance(msg.sender), "!gov");
  }

  // *************************************************************
  //                        VIEWS
  // *************************************************************

  /// @dev Return true if a new epoch can be started.
  function isReadyToStart() public view returns (bool) {
    return startEpochTS + EPOCH_LENGTH < block.timestamp;
  }

  // *************************************************************
  //                      GOV ACTIONS
  // *************************************************************

  /// @dev Change operator address.
  function changeOperator(address _operator) external {
    _olyGov();
    require(_operator != address(0), "WRONG_INPUT");

    operator = _operator;
    emit OperatorChanged(_operator);
  }

  /// @dev Set minimal amount of token for starting new epoch.
  function setMinAmountPerEpoch(uint value) external {
    _olyGov();
    minAmountPerEpoch = value;
    emit MinAmountPerEpochChanged(value);
  }

  /// @dev How much % of tokens will go to VeDistributor
  function setToVeRatio(uint value) external {
    _olyGov();
    require(value <= RATIO_DENOMINATOR, "too high");
    toVeRatio = value;
    emit ToVeRatioChanged(value);
  }

  // *************************************************************
  //                      MAIN LOGIC
  // *************************************************************

  /// @dev Start new epoch with given token amount.
  ///      Amount should be higher than token balance and `minAmountPerEpoch`.
  ///      With zero amount we will just start a new epoch without additional rewards.
  function startEpoch(uint amount) external {
    _onlyOperator();

    require(isReadyToStart(), "too early");
    address _token = token;
    uint balance = IERC20(_token).balanceOf(address(this));
    require(amount <= balance && amount >= minAmountPerEpoch, "!amount");

    IController _controller = IController(controller());

    uint toVe = amount * toVeRatio / RATIO_DENOMINATOR;
    uint toVoter = amount - toVe;

    if (toVe != 0) {
      address veDistributor = _controller.veDistributor();
      IERC20(_token).safeTransfer(veDistributor, toVe);
      IVeDistributor(veDistributor).checkpoint();
      IVeDistributor(veDistributor).checkpointTotalSupply();
    }

    if (toVoter != 0) {
      address tetuVoter = _controller.voter();
      _approveIfNeed(_token, tetuVoter, toVoter);
      IVoter(tetuVoter).notifyRewardAmount(toVoter);
    }

    address _bribe = bribe;
    IBribe(_bribe).increaseEpoch();

    startEpochTS = block.timestamp;
    epoch++;

    emit EpochStarted(epoch, startEpochTS, balance, toVe, toVoter);
  }

  // *************************************************************
  //                    INTERNAL LOGIC
  // *************************************************************

  function _approveIfNeed(address _token, address dst, uint amount) internal {
    if (IERC20(_token).allowance(address(this), dst) < amount) {
      IERC20(_token).safeApprove(dst, 0);
      IERC20(_token).safeApprove(dst, type(uint).max);
    }
  }

}
