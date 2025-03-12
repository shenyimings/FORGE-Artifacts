// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { Ownable } from "../../utils/Ownable.sol";
import { ConversionPool } from "../ConversionPool.sol";
import { ConversionPoolV2 } from "../ConversionPoolV2.sol";
import { IProxy } from "../../upgradeability/Proxy.sol";

contract ConversionPoolUpgraderV1Helper {
  address private proxy;

  constructor(address _proxy) {
    proxy = _proxy;
  }

  function inputToken() external view returns (address) {
    return address(ConversionPool(proxy).inputToken());
  }

  function outputToken() external view returns (address) {
    return address(ConversionPool(proxy).outputToken());
  }

  function swapper() external view returns (address) {
    return address(ConversionPool(proxy).swapper());
  }

  function proxyInputToken() external view returns (address) {
    return address(ConversionPool(proxy).proxyInputToken());
  }

  function proxyOutputToken() external view returns (address) {
    return address(ConversionPool(proxy).proxyOutputToken());
  }

  function proxyReserve() external view returns (uint256) {
    return ConversionPool(proxy).proxyReserve();
  }

  function router() external view returns (address) {
    return ConversionPool(proxy).optRouter();
  }

  function feeder() external view returns (address) {
    return address(ConversionPool(proxy).feeder());
  }

  function isDepositAllowed() external view returns (bool) {
    return ConversionPool(proxy).isDepositAllowed();
  }

  function isRedemptionAllowed() external view returns (bool) {
    return ConversionPool(proxy).isRedemptionAllowed();
  }

  function destroy() external {
    selfdestruct(msg.sender);
  }
}

contract ConversionPoolUpgraderV1 is Ownable {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  function upgrade(address proxy, address proxyAdmin) public onlyOwner {
    require(address(this) == IProxy(proxy).admin(), "Upgrader: unauthorized");

    ConversionPoolUpgraderV1Helper helper = new ConversionPoolUpgraderV1Helper(
      proxy
    );

    // tokens
    address inputToken = helper.inputToken();
    address outputToken = helper.outputToken();
    address proxyInputToken = helper.proxyInputToken();
    address proxyOutputToken = helper.proxyOutputToken();
    uint256 proxyReserve = helper.proxyReserve();

    // utils
    address swapper = helper.swapper();
    address router = helper.router();
    address feeder = helper.feeder();

    // access control
    bool isDepositAllowed = helper.isDepositAllowed();
    bool isRedemptionAllowed = helper.isRedemptionAllowed();

    address v2Impl = address(new ConversionPoolV2());
    IProxy(proxy).upgradeTo(v2Impl);
    IProxy(proxy).changeAdmin(proxyAdmin);

    // now conversion pool v1 proxy follows conversion pool v2 logic
    ConversionPoolV2 poolV2 = ConversionPoolV2(proxy);

    // test state storage

    // token state
    require(
      inputToken == address(poolV2.inputToken()) &&
        outputToken == address(poolV2.outputToken()) &&
        proxyInputToken == address(poolV2.proxyInputToken()) &&
        proxyOutputToken == address(poolV2.proxyOutputToken()) &&
        proxyReserve == poolV2.proxyReserve(),
      "Upgrader: token state validation failed"
    );

    // util state
    require(
      swapper == address(poolV2.swapper()) &&
        router == address(poolV2.optRouter()) &&
        feeder == address(poolV2.feeder()),
      "Upgrader: util state validation failed"
    );

    // access control
    require(
      isDepositAllowed == poolV2.isDepositAllowed() &&
        isRedemptionAllowed == poolV2.isRedemptionAllowed(),
      "Upgrader: access control state validation failed"
    );

    helper.destroy();
    selfdestruct(msg.sender);
  }
}
