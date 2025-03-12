// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../proxy/ControllableV3.sol";
import "../openzeppelin/SafeERC20.sol";
import "../openzeppelin/EnumerableSet.sol";

/// @title Upgradable contract with assets for invest in different places under control of Tetu platform.
/// @author belbix
contract InvestFundV2 is ControllableV3 {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  // *************************************************************
  //                        CONSTANTS
  // *************************************************************

  /// @dev Version of this contract. Adjust manually on each code modification.
  string public constant INVEST_FUND_VERSION = "2.0.0";

  // *************************************************************
  //                        VARIABLES
  //                Keep names and ordering!
  //                 Add only in the bottom.
  // *************************************************************

  EnumerableSet.AddressSet internal _tokens;

  // *************************************************************
  //                        EVENTS
  // *************************************************************

  event FundDeposit(address indexed token, uint256 amount);
  event FundWithdrawn(address indexed token, uint256 amount);

  // *************************************************************
  //                         INIT
  // *************************************************************

  /// @notice Initialize contract after setup it as proxy implementation
  function init(address __controller) external initializer {
    __Controllable_init(__controller);
  }

  // *************************************************************
  //                      RESTRICTIONS
  // *************************************************************

  /// @dev Allow operation only for Controller
  modifier onlyGov() {
    require(isGovernance(msg.sender), "!gov");
    _;
  }

  // *************************************************************
  //                         VIEWS
  // *************************************************************

  function tokens() external view returns (address[] memory) {
    return _tokens.values();
  }

  // *************************************************************
  //                     GOVERNANCE ACTIONS
  // *************************************************************

  /// @dev Move tokens to governance gnosis safe
  function withdraw(address _token, uint256 amount) external onlyGov {
    IERC20(_token).safeTransfer(msg.sender, amount);
    emit FundWithdrawn(_token, amount);
  }

  /// @dev Transfer any token to this contract. The token will be added in the token list.
  function deposit(address _token, uint256 amount) external onlyGov {
    _tokens.add(_token);
    if (amount != 0) {
      IERC20(_token).safeTransferFrom(msg.sender, address(this), amount);
    }
    emit FundDeposit(_token, amount);
  }

  // *************************************************************
  //                      FUND CONTROL
  // *************************************************************

  // TBD - implement invest strategy
  // implementation highly depends on the Tetu Second Stage

}
