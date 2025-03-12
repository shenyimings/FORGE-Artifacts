pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./IAUSC.sol";
import "./IPoolEscrow.sol";

contract BasicRebaser {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  event Updated(uint256 xau, uint256 ausc);
  event NoUpdateXAU();
  event NoUpdateAUSC();
  event NoSecondaryMint();
  event NoRebaseNeeded();
  event StillCold();
  event NotInitialized();

  uint256 public constant BASE = 1e18;
  uint256 public constant WINDOW_SIZE = 12;

  address public ausc;
  uint256[] public pricesXAU = new uint256[](12);
  uint256[] public pricesAUSC = new uint256[](12);
  uint256 public pendingXAUPrice = 0;
  uint256 public pendingAUSCPrice = 0;
  bool public noPending = true;
  uint256 public averageXAU;
  uint256 public averageAUSC;
  uint256 public lastUpdate;
  uint256 public frequency = 1 hours;
  uint256 public counter = 0;
  uint256 public epoch = 1;
  address public secondaryPool;
  address public governance;

  uint256 public nextRebase = 0;
  uint256 public constant REBASE_DELAY = 12 hours;

  modifier onlyGov() {
    require(msg.sender == governance, "only gov");
    _;
  }

  constructor (address token, address _secondaryPool) public {
    ausc = token;
    secondaryPool = _secondaryPool;
    governance = msg.sender;
  }

  function setNextRebase(uint256 next) external onlyGov {
    require(nextRebase == 0, "Only one time activation");
    nextRebase = next;
  }

  function setGovernance(address account) external onlyGov {
    governance = account;
  }

  function setSecondaryPool(address pool) external onlyGov {
    secondaryPool = pool;
  }

  function checkRebase() external {
    // ausc ensures that we do not have smart contracts rebasing
    require (msg.sender == address(ausc), "only through ausc");
    rebase();
    recordPrice();
  }

  function recordPrice() public {
    if (msg.sender != tx.origin && msg.sender != address(ausc)) {
      // smart contracts could manipulate data via flashloans,
      // thus we forbid them from updating the price
      return;
    }

    if (block.timestamp < lastUpdate + frequency) {
      // addition is running on timestamps, this will never overflow
      // we leave at least the specified period between two updates
      return;
    }

    (bool successXAU, uint256 priceXAU) = getPriceXAU();
    (bool successAUSC, uint256 priceAUSC) = getPriceAUSC();
    if (!successAUSC) {
      // price of AUSC was not returned properly
      emit NoUpdateAUSC();
      return;
    }
    if (!successXAU) {
      // price of XAU was not returned properly
      emit NoUpdateXAU();
      return;
    }
    lastUpdate = block.timestamp;

    if (noPending) {
      // we start recording with 1 hour delay
      pendingXAUPrice = priceXAU;
      pendingAUSCPrice = priceAUSC;
      noPending = false;
    } else if (counter < WINDOW_SIZE) {
      // still in the warming up phase
      averageXAU = averageXAU.mul(counter).add(pendingXAUPrice).div(counter.add(1));
      averageAUSC = averageAUSC.mul(counter).add(pendingAUSCPrice).div(counter.add(1));
      pricesXAU[counter] = pendingXAUPrice;
      pricesAUSC[counter] = pendingAUSCPrice;
      pendingXAUPrice = priceXAU;
      pendingAUSCPrice = priceAUSC;
      counter++;
    } else {
      uint256 index = counter % WINDOW_SIZE;
      averageXAU = averageXAU.mul(WINDOW_SIZE).sub(pricesXAU[index]).add(pendingXAUPrice).div(WINDOW_SIZE);
      averageAUSC = averageAUSC.mul(WINDOW_SIZE).sub(pricesAUSC[index]).add(pendingAUSCPrice).div(WINDOW_SIZE);
      pricesXAU[index] = pendingXAUPrice;
      pricesAUSC[index] = pendingAUSCPrice;
      pendingXAUPrice = priceXAU;
      pendingAUSCPrice = priceAUSC;
      counter++;
    }
    emit Updated(pendingXAUPrice, pendingAUSCPrice);
  }

  function rebase() public {
    // make public rebasing only after initialization
    if (nextRebase == 0 && msg.sender != governance) {
      emit NotInitialized();
      return;
    }
    if (counter <= WINDOW_SIZE && msg.sender != governance) {
      emit StillCold();
      return;
    }
    // We want to rebase only at 1pm UTC and 12 hours later
    if (block.timestamp < nextRebase) {
      return;
    } else {
      nextRebase = nextRebase + REBASE_DELAY;
    }

    // only rebase if there is a 5% difference between the price of XAU and AUSC
    uint256 highThreshold = averageXAU.mul(105).div(100);
    uint256 lowThreshold = averageXAU.mul(95).div(100);

    if (averageAUSC > highThreshold) {
      // AUSC is too expensive, this is a positive rebase increasing the supply
      uint256 currentSupply = IERC20(ausc).totalSupply();
      uint256 desiredSupply = currentSupply.mul(averageAUSC).div(averageXAU);
      uint256 secondaryPoolBudget = desiredSupply.sub(currentSupply).mul(10).div(100);
      desiredSupply = desiredSupply.sub(secondaryPoolBudget);

      // Cannot underflow as desiredSupply > currentSupply, the result is positive
      // delta = (desiredSupply / currentSupply) * 100 - 100
      uint256 delta = desiredSupply.mul(BASE).div(currentSupply).sub(BASE);
      IAUSC(ausc).rebase(epoch, delta, true);

      if (secondaryPool != address(0)) {
        // notify the pool escrow that tokens are available
        IAUSC(ausc).mint(address(this), secondaryPoolBudget);
        IERC20(ausc).safeApprove(secondaryPool, 0);
        IERC20(ausc).safeApprove(secondaryPool, secondaryPoolBudget);
        IPoolEscrow(secondaryPool).notifySecondaryTokens(secondaryPoolBudget);
      } else {
        emit NoSecondaryMint();
      }
      epoch++;
    } else if (averageAUSC < lowThreshold) {
      // AUSC is too cheap, this is a negative rebase decreasing the supply
      uint256 currentSupply = IERC20(ausc).totalSupply();
      uint256 desiredSupply = currentSupply.mul(averageAUSC).div(averageXAU);

      // Cannot overflow as desiredSupply > currentSupply
      // delta = 100 - (desiredSupply / currentSupply) * 100
      uint256 delta = uint256(BASE).sub(desiredSupply.mul(BASE).div(currentSupply));
      IAUSC(ausc).rebase(epoch, delta, false);
      epoch++;
    } else {
      // else the price is within bounds
      emit NoRebaseNeeded();
    }
  }

  /**
  * Calculates how a rebase would look if it was triggered now.
  */
  function calculateRealTimeRebase() public view returns (uint256, uint256) {
    // only rebase if there is a 5% difference between the price of XAU and AUSC
    uint256 highThreshold = averageXAU.mul(105).div(100);
    uint256 lowThreshold = averageXAU.mul(95).div(100);

    if (averageAUSC > highThreshold) {
      // AUSC is too expensive, this is a positive rebase increasing the supply
      uint256 currentSupply = IERC20(ausc).totalSupply();
      uint256 desiredSupply = currentSupply.mul(averageAUSC).div(averageXAU);
      uint256 secondaryPoolBudget = desiredSupply.sub(currentSupply).mul(10).div(100);
      desiredSupply = desiredSupply.sub(secondaryPoolBudget);

      // Cannot underflow as desiredSupply > currentSupply, the result is positive
      // delta = (desiredSupply / currentSupply) * 100 - 100
      uint256 delta = desiredSupply.mul(BASE).div(currentSupply).sub(BASE);
      return (delta, secondaryPool == address(0) ? 0 : secondaryPoolBudget);
    } else if (averageAUSC < lowThreshold) {
      // AUSC is too cheap, this is a negative rebase decreasing the supply
      uint256 currentSupply = IERC20(ausc).totalSupply();
      uint256 desiredSupply = currentSupply.mul(averageAUSC).div(averageXAU);

      // Cannot overflow as desiredSupply > currentSupply
      // delta = 100 - (desiredSupply / currentSupply) * 100
      uint256 delta = uint256(BASE).sub(desiredSupply.mul(BASE).div(currentSupply));
      return (delta, 0);
    } else {
      return (0,0);
    }
  }

  function getPriceXAU() public view returns (bool, uint256);
  function getPriceAUSC() public view returns (bool, uint256);
}
