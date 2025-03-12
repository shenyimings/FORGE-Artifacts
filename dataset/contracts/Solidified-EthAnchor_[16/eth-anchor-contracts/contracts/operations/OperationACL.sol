// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;
pragma experimental ABIEncoderV2;

import { Context } from "@openzeppelin/contracts/utils/Context.sol";

abstract contract OperationACL is Context {
  address public owner;
  address public router;
  address public controller;

  constructor() {
    owner = _msgSender();
    router = _msgSender();
    controller = _msgSender();
  }

  modifier onlyOwner {
    require(_msgSender() == owner, "OperationACL: owner access denied");

    _;
  }

  modifier onlyRouter {
    require(_msgSender() == router, "OperationACL: router access denied");

    _;
  }

  modifier onlyController {
    require(
      _msgSender() == controller,
      "OperationACL: controller access denied"
    );

    _;
  }

  modifier onlyGranted {
    address sender = _msgSender();
    require(
      sender == owner || sender == router || sender == controller,
      "OperationACL: denied"
    );

    _;
  }

  function transferOwnership(address _owner) public onlyOwner {
    require(_owner != address(0x0), "OperationACL: invalid owner address");
    owner = _owner;
  }

  function transferRouter(address _router) public onlyOwner {
    require(_router != address(0x0), "OperationACL: invalid router address");
    router = _router;
  }

  function transferController(address _controller) public onlyOwner {
    require(
      _controller != address(0x0),
      "OperationACL: invalid controller address"
    );
    controller = _controller;
  }
}
