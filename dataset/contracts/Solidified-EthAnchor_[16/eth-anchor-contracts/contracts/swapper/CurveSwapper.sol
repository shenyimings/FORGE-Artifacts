// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;
pragma experimental ABIEncoderV2;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { Ownable } from "../utils/Ownable.sol";
import { ISwapper } from "./ISwapper.sol";

interface ICurve {
  function N_COINS() external view returns (int128);

  function BASE_N_COINS() external view returns (int128);

  function coins(uint256 i) external view returns (address); // pool

  function base_coins(uint256 i) external view returns (address); // base_pool

  function get_dy(
    int128 i,
    int128 j,
    uint256 dx
  ) external view returns (uint256);

  function get_dy_underlying(
    int128 i,
    int128 j,
    uint256 dx
  ) external view returns (uint256);

  function exchange(
    int128 i,
    int128 j,
    uint256 dx,
    uint256 min_dy
  ) external returns (uint256);

  function exchange_underlying(
    int128 i,
    int128 j,
    uint256 dx,
    uint256 min_dy
  ) external returns (uint256);
}

contract CurveSwapper is ISwapper, Ownable {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  struct Route {
    address[] pools;
    int128[] indexes;
  }

  mapping(address => mapping(address => Route)) private routes;

  function getRoute(address _from, address _to)
    public
    view
    returns (Route memory)
  {
    return routes[_from][_to];
  }

  function setRoute(
    address _from,
    address _to,
    address[] memory _pools,
    address[] memory _tokens,
    int128[] memory _indexes
  ) public onlyOwner {
    require(_indexes.length >= 2, "CurveSwapper: INVALID_PATH");
    require(
      _pools.length.mul(2) == _indexes.length,
      "CurveSwapper: INVAILD_LENGTH"
    );
    Route storage route = routes[_from][_to];
    route.pools = _pools;
    route.indexes = _indexes;

    for (uint256 i = 0; i < route.pools.length; i++) {
      if (IERC20(_tokens[i]).allowance(address(this), _pools[i]) == 0) {
        IERC20(_tokens[i]).safeApprove(_pools[i], type(uint256).max);
      }
    }
  }

  function swapToken(
    address _from, // ignore
    address _to, // ignore
    uint256 _amount,
    uint256 _minAmountOut,
    address _beneficiary // ignore
  ) public override {
    IERC20(_from).safeTransferFrom(msg.sender, address(this), _amount);

    Route memory route = routes[_from][_to];
    require(route.pools.length > 0, "CurveSwapper: ROUTE_NOT_SUPPORTED");

    uint256 amount = _amount;
    for (uint256 i = 0; i < route.pools.length; i++) {
      amount = ICurve(route.pools[i]).exchange_underlying(
        route.indexes[i.mul(2)],
        route.indexes[i.mul(2).add(1)],
        amount,
        0
      );
    }

    require(amount >= _minAmountOut, "CurveSwapper: INVALID_SWAP_RESULT");
    IERC20(_to).safeTransfer(
      _beneficiary,
      IERC20(_to).balanceOf(address(this))
    );
  }
}
