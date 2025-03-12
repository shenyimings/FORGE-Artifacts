// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";

contract MoneyMarketForTest {
  using SafeTransferLib for ERC20;

  address internal immutable owner;
  address internal borrower;
  uint256 internal interestRatePerSec;

  mapping(address => mapping(address => uint256)) public getNonCollatAccountDebt;
  mapping(address => uint256) public lastAccrualOf;

  modifier onlyBorrower() {
    require(msg.sender == borrower, "NB");
    _;
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "NO");
    _;
  }

  constructor() {
    owner = msg.sender;
  }

  function accrueInterest(address token) public {
    uint256 timePassed = block.timestamp - lastAccrualOf[token];
    if (timePassed == 0) return;
    getNonCollatAccountDebt[borrower][token] +=
      getNonCollatAccountDebt[borrower][token] * timePassed * interestRatePerSec / 1e18;
    lastAccrualOf[token] = block.timestamp;
  }

  function nonCollatBorrow(address token, uint256 amount) external onlyBorrower {
    accrueInterest(token);
    getNonCollatAccountDebt[borrower][token] += amount;
    ERC20(token).safeTransfer(msg.sender, amount);
  }

  function nonCollatRepay(address, address token, uint256 amount) external {
    accrueInterest(token);
    ERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    getNonCollatAccountDebt[borrower][token] -= amount;
  }

  function withdrawTokens(address[] calldata tokens) external onlyOwner {
    uint256 len = tokens.length;
    ERC20 token;
    for (uint256 i; i < len;) {
      token = ERC20(tokens[i]);
      token.safeTransfer(owner, token.balanceOf(address(this)));
      unchecked {
        ++i;
      }
    }
  }

  function injectFund(address _token, uint256 _amount) external {
    ERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
  }

  function setInterestRatePerSec(uint256 newRate) external onlyOwner {
    interestRatePerSec = newRate;
  }

  function setBorrower(address _borrower) external onlyOwner {
    borrower = _borrower;
  }

  function getMinDebtSize() external pure returns (uint256) {
    return 0;
  }
}
