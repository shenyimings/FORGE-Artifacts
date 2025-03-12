pragma solidity 0.4.24;

/*
 * This is an example of how we would upgrade the AccessToken contract if we had to.
 * Instead of doing a full data migration from ACTv1 to ACTv2, we could make
 * use of inheritance to keep the old functionality we want and change what is needed.
 * We could then contact the old contract to retrieve old balances.
 *
 * NOTE: This should probably only be done once because every subsequent
 * update will get more confusing. If we really have to update the ACT
 * contract we should investigate then whether we should just use
 * the same proxy pattern we are using for the POA contract.
 */

import "../AccessToken.sol";


contract AccessTokenUpgradeExample is AccessToken {

  constructor(address _registry)
    public
    AccessToken(_registry)
  {}

  function balanceOf(address _address)
    public
    view
    returns (uint256)
  {
    return totalMintedActPerLockedBbkToken == 0
      ? 0
      : AccessToken(
        registry.getContractAddress("AccessTokenOld")
      ).balanceOf(_address)
      .add(lockedBbkPerUser[_address])
      .mul(totalMintedActPerLockedBbkToken.sub(mintedActPerUser[_address]))
      .div(1e18)
      .add(mintedActFromPastLockPeriodsPerUser[_address])
      .add(receivedAct[_address])
      .sub(spentAct[_address]);
  }
}
