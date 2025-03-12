pragma solidity 0.5.16;

import "./distribution/SnxPool.sol";

contract Rewarder is Ownable {

  event Notified(address);

  constructor() public {}

  function notify(address[] memory pools, uint256 amount, address ausc, uint256 auscAmount) public onlyOwner {
    for (uint256 i = 0; i < pools.length; i++) {
      // notify pool
      AuricRewards(pools[i]).notifyRewardAmount(amount);
      emit Notified(pools[i]);

      // transfer to pool's escow
      PoolEscrow escrow = PoolEscrow(AuricRewards(pools[i]).escrow());
      IERC20(ausc).transferFrom(msg.sender, address(escrow), auscAmount);

      // revert transaction if anything is wrong
      require(address(escrow) != address(0), "escrow not set");
      require(IERC20(escrow.shareToken()).balanceOf(pools[i]) == amount, "wrong amount");
    }
  }
}
