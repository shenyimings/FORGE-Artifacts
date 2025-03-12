//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0;
pragma abicoder v2;

import "forge-std/Test.sol";

import "../../../contracts/arbitrum/AddressAliasHelper.sol";

contract MockInbox is Test {
  uint256 ticketNum;

  constructor() {
    ticketNum = uint256(1);
  }

  function createRetryableTicket(
    address destAddr,
    uint256, // arbTxCallValue
    uint256, // maxSubmissionCost
    address, // submissionRefundAddress
    address, // valueRefundAddress
    uint256 maxGas,
    uint256, // gasPriceBid
    bytes calldata data
  ) external payable returns (uint256) {
    bool success;

    vm.stopPrank();
    vm.startPrank(AddressAliasHelper.applyL1ToL2Alias(msg.sender));
    (success, ) = destAddr.call{gas: maxGas}(data);
    vm.stopPrank();

    require(
      success,
      "MockInbox::createRetryableTicket: Message execution reverted."
    );
    ticketNum += 1;
    return uint256(ticketNum);
  }
}
