pragma solidity ^0.4.18;

import './math/SafeMath.sol';
import "./ownership/Owners.sol";
import "./tokens/REIDAOMintableBurnableLockableToken.sol";
import "./registries/AddressesEternalStorage.sol";
import "./registries/CRPAllocationConfig.sol";
import "./registries/CRPGenerationConfig.sol";

contract CRPGeneration is Owners(true) {
  using SafeMath for uint256;

  enum State { Active, Inactive }
  State public state;
  REIDAOMintableBurnableLockableToken crvToken;
  REIDAOMintableBurnableLockableToken crpToken;
  bytes32 public defaultPlan;

  AddressesEternalStorage eternalStorage;
  CRPGenerationConfig crpGenerationConfig;
  CRPAllocationConfig crpAllocationConfig;

  /**
   * @dev initializes contract with parameter
   * @param       _eternalStorage AddressesEternalStorage the address of eternal storage
   */
  function CRPGeneration(AddressesEternalStorage _eternalStorage) public {
    defaultPlan = "default";
    state = State.Active;
    eternalStorage = _eternalStorage;
    crvToken = REIDAOMintableBurnableLockableToken(eternalStorage.getEntry("CRVToken"));
    crpToken = REIDAOMintableBurnableLockableToken(eternalStorage.getEntry("CRPToken"));
  }

  /**
   * @notice generates CRP according to the deault plan.
   * @dev public method
   */
  function () public payable {
    generateCRP(defaultPlan, crvToken.balanceOf(msg.sender));
  }

  /**
   * @notice generates CRP according to the plan config (from CRPGenerationConfig),
   * and according to the allocation config (from crpAllocationConfig).
   * eternalStorage stores the addresses of both config contracts.
   * Only proceed is the state of the contact is active, and the generation plan is active.
   * @dev public method
   * @param _plan bytes32 the name of the plan to be used to generate CRP
   * @param crvToken uint total number of CRV tokens activated (to be locked)
   */
  function generateCRP(bytes32 _plan, uint crvToLock) public payable {
    require(state == State.Active);
    uint transferrableCRV = crvToken.transferableTokens(msg.sender);
    require (crvToLock <= transferrableCRV);

    crpGenerationConfig = CRPGenerationConfig(eternalStorage.getEntry("CRPGenerationConfig"));
    crpAllocationConfig = CRPAllocationConfig(eternalStorage.getEntry("CRPAllocationConfig"));
    var (crpPerCrv, crvLockPeriod, initPct, subseqPct, subseqFreq, subseqFreqIntervalDays, isActive) = crpGenerationConfig.configs(_plan);
    require(isActive);

    crvToken.lockTokens(msg.sender, crvToLock, now + crvLockPeriod);

    uint crpToMint = crvToLock.mul(crpPerCrv);
    uint crpForTokenHolder = crpToMint.mul(crpAllocationConfig.getConfig("tokenHolder")).div(100);

    //release 50% CRP allocated for token holder immediately
    crpToken.mint(msg.sender, crpForTokenHolder.mul(initPct).div(100));

    //release remaining CRP allocated for token holder in 5 batches.
    for (uint i=0; i<subseqFreq; i++) {
      crpToken.mintAndLockTokens(msg.sender, crpForTokenHolder.mul(subseqPct).div(100), now + (subseqFreqIntervalDays * (i+1)));
    }
    mintTokensForOtherParties(crpToMint);
  }

  /**
   * @notice mints CRP tokens for parties other than token holders
   * @dev internal call only
   * @param crpToMint uint the total amount of generated CRP.
   */
  function mintTokensForOtherParties(uint crpToMint) internal {
    uint crpForCrowdvillaNpo  = crpToMint.mul(crpAllocationConfig.getConfig("crowdvillaNpo")).div(100);
    uint crpForCrowdvillaOps  = crpToMint.mul(crpAllocationConfig.getConfig("crowdvillaOps")).div(100);
    uint crpForReidao         = crpToMint.mul(crpAllocationConfig.getConfig("reidao")).div(100);

    crpToken.mint(eternalStorage.getEntry("CRPWalletCrowdvillaNpo"), crpForCrowdvillaNpo);
    crpToken.mint(eternalStorage.getEntry("CRPWalletCrowdvillaOps"), crpForCrowdvillaOps);
    crpToken.mint(eternalStorage.getEntry("CRPWalletReidao"), crpForReidao);
  }

  /**
   * @notice updates the default plan name.
   * @dev can only by called by owners
   * @param _defaultPlan bytes32 the name ot the new default plan
   */
  function changeDefaultPlan(bytes32 _defaultPlan) public ownerOnly {
    defaultPlan = _defaultPlan;
  }

  /**
   * @notice activates the state of contract.
   * @dev can only by called by owners
   */
  function activateState() public ownerOnly {
    state = State.Active;
  }

  /**
   * @notice deactivates the state of contract.
   * @dev can only by called by owners
   */
  function inactivateState() public ownerOnly {
    state = State.Inactive;
  }
}
