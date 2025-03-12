// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { Ownable } from "../../utils/Ownable.sol";
import { Router } from "../Router.sol";
import { RouterV2 } from "../RouterV2.sol";
import { IProxy } from "../../upgradeability/Proxy.sol";

contract RouterUpgraderV1Helper {
  address private proxy;

  constructor(address _proxy) {
    proxy = _proxy;
  }

  function store() external view returns (address) {
    return Router(proxy).optStore();
  }

  function stdId() external view returns (uint256) {
    return Router(proxy).optStdId();
  }

  function factory() external view returns (address) {
    return Router(proxy).optFactory();
  }

  function wUST() external view returns (address) {
    return Router(proxy).wUST();
  }

  function aUST() external view returns (address) {
    return Router(proxy).aUST();
  }

  function destroy() external {
    selfdestruct(msg.sender);
  }
}

contract RouterUpgraderV1 is Ownable {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  event DepositReturns(address indexed operation);
  event RedeemReturns(address indexed operation);

  function upgrade(address proxy, address proxyAdmin) public onlyOwner {
    require(address(this) == IProxy(proxy).admin(), "Upgrader: unauthorized");

    RouterUpgraderV1Helper helper = new RouterUpgraderV1Helper(proxy);

    address store = helper.store();
    uint256 stdId = helper.stdId();
    address factory = helper.factory();
    address wUST = helper.wUST();
    address aUST = helper.aUST();

    address v2Impl = address(new RouterV2());
    IProxy(proxy).upgradeTo(v2Impl);
    IProxy(proxy).changeAdmin(proxyAdmin);

    // now router v1 proxy follows routerV2 logic
    RouterV2 routerV2 = RouterV2(proxy);

    // test state storage
    require(
      store == routerV2.optStore() &&
        stdId == routerV2.optStdId() &&
        factory == routerV2.optFactory() &&
        wUST == routerV2.wUST() &&
        aUST == routerV2.aUST(),
      "Upgrader: validation failed"
    );

    uint256 amount = uint256(1e18).mul(10);

    IERC20(wUST).safeTransferFrom(msg.sender, address(this), amount);
    IERC20(wUST).safeIncreaseAllowance(proxy, amount);
    emit DepositReturns(routerV2.depositStable(msg.sender, amount));

    IERC20(aUST).safeTransferFrom(msg.sender, address(this), amount);
    IERC20(aUST).safeIncreaseAllowance(proxy, amount);
    emit RedeemReturns(routerV2.redeemStable(msg.sender, amount));

    // destroy
    helper.destroy();
    selfdestruct(msg.sender);
  }
}
