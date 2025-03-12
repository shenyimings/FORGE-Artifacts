pragma solidity 0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract Escrow {

  using SafeERC20 for IERC20;

  address public token;
  address public governance;

  modifier onlyGov() {
    require(msg.sender == governance, "only gov");
    _;
  }

  constructor () public {
    governance = msg.sender;
  }

  function approve(address token, address to, uint256 amount) public onlyGov {
    IERC20(token).safeApprove(to, 0);
    IERC20(token).safeApprove(to, amount);
  }

  function transfer(address token, address to, uint256 amount) public onlyGov {
    IERC20(token).safeTransfer(to, amount);
  }

  function setGovernance(address account) external onlyGov {
    governance = account;
  }
}
