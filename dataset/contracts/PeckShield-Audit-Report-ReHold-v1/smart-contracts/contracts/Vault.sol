// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/IVault.sol";
import "./interfaces/IWETH.sol";

contract Vault is AccessControl, IVault {
  using SafeERC20 for IERC20;

  address public immutable WETH;
  address payable public immutable bucket;

  mapping(address => uint256) private _thresholds;
  address[] private _tokens;
  struct Threshold {
    address token;
    uint256 amount;
  }

  constructor(address _WETH) {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

    WETH = _WETH;
    bucket = payable(msg.sender);
  }

  receive() external payable {}

  function deposit() external payable {
    if (_shouldSendToBucket(WETH, msg.value)) {
      _withdraw(bucket, msg.value);
    }
  }

  function withdraw(address payable to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _withdraw(to, amount);
  }

  function _withdraw(address payable to, uint256 amount) private {
    require(to.send(amount), "Vault: Sending ETH has been failed");
  }

  function depositTokens(address token, address from, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (_shouldSendToBucket(token, amount)) {
      if (token == WETH) {
        IERC20(token).safeTransferFrom(from, address(this), amount);
        IWETH(WETH).withdraw(amount);
        _withdraw(bucket, amount);
      } else {
        IERC20(token).safeTransferFrom(from, bucket, amount);
      }
    } else {
      IERC20(token).safeTransferFrom(from, address(this), amount);

      if (token == WETH) {
        IWETH(WETH).withdraw(amount);
      }
    }
  }

  function withdrawTokens(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (token == WETH) {
      IWETH(WETH).deposit{value: amount}();
    }

    IERC20(token).safeTransfer(to, amount);
  }

  function updateThreshold(address token, uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
    if (_thresholds[token] == 0) {
      _tokens.push(token);
    }

    _thresholds[token] = amount;
  }

  function thresholds() public view returns (Threshold[] memory ts) {
    ts = new Threshold[](_tokens.length);

    for (uint32 i = 0; i < _tokens.length; i++) {
      ts[i] = Threshold(_tokens[i], _thresholds[_tokens[i]]);
    }
  }

  function _shouldSendToBucket(address token, uint256 amount) private view returns (bool) {
    return amount > _thresholds[token];
  }
}
