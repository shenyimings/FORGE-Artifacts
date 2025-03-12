// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import { Math } from "../utils/Math.sol";

contract Vester is ReentrancyGuardUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  uint256 private constant YEAR = 365 days;

  // ---------------------
  //       Events
  // ---------------------

  event Vest(
    address indexed owner,
    uint256 indexed itemIndex,
    uint256 amount,
    uint256 startTime,
    uint256 endTime
  );

  event Claim(
    address indexed owner,
    uint256 indexed itemIndex,
    uint256 vestedAmount,
    uint256 unusedAmount
  );

  event Cancel(
    address indexed owner,
    uint256 indexed itemIndex,
    uint256 returnAmount
  );

  // ---------------------
  //       Errors
  // ---------------------
  error BadArgument();
  error ExceedMaxDuration();
  error Unauthorized();
  error Claimed();
  error HasNotCompleted();
  error HasCompleted();

  // ---------------------
  //       Structs
  // ---------------------
  struct Item {
    address owner;
    bool hasClaimed;
    uint256 amount;
    uint256 startTime;
    uint256 endTime;
  }

  // ---------------------
  //       States
  // ---------------------
  address public esP88;
  address public p88;

  address public vestedEsp88Destination;
  address public unusedEsp88Destination;

  Item[] public items;

  function initialize(
    address esP88Address,
    address p88Address,
    address vestedEsp88DestinationAddress,
    address unusedEsp88DestinationAddress
  ) external initializer {
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    esP88 = esP88Address;
    p88 = p88Address;
    vestedEsp88Destination = vestedEsp88DestinationAddress;
    unusedEsp88Destination = unusedEsp88DestinationAddress;
  }

  function vestFor(
    address account,
    uint256 amount,
    uint256 duration
  ) external nonReentrant {
    if (amount == 0) revert BadArgument();
    if (duration > YEAR) revert ExceedMaxDuration();

    Item memory item = Item({
      owner: account,
      amount: amount,
      startTime: block.timestamp,
      endTime: block.timestamp + duration,
      hasClaimed: false
    });

    items.push(item);

    IERC20Upgradeable(esP88).safeTransferFrom(
      msg.sender,
      address(this),
      amount
    );

    emit Vest(
      item.owner,
      items.length - 1,
      amount,
      item.startTime,
      item.endTime
    );
  }

  function claimFor(address account, uint256 itemIndex) external nonReentrant {
    _claimFor(account, itemIndex);
  }

  function claimFor(address account, uint256[] memory itemIndexes)
    external
    nonReentrant
  {
    for (uint256 i = 0; i < itemIndexes.length; i++) {
      _claimFor(account, itemIndexes[i]);
    }
  }

  function _claimFor(address account, uint256 itemIndex) internal {
    Item storage item = items[itemIndex];

    if (item.owner != account) revert Unauthorized();
    if (item.hasClaimed) revert Claimed();
    if (item.endTime > block.timestamp) revert HasNotCompleted();

    item.hasClaimed = true;

    uint256 claimable = getUnlockAmount(
      item.amount,
      item.endTime - item.startTime
    );

    IERC20Upgradeable(p88).safeTransfer(account, claimable);

    IERC20Upgradeable(esP88).safeTransfer(vestedEsp88Destination, claimable);

    IERC20Upgradeable(esP88).safeTransfer(
      unusedEsp88Destination,
      item.amount - claimable
    );

    emit Claim(item.owner, itemIndex, claimable, item.amount - claimable);
  }

  function abort(uint256 itemIndex) external nonReentrant {
    Item storage item = items[itemIndex];

    if (msg.sender != item.owner) revert Unauthorized();
    if (item.hasClaimed) revert Claimed();

    uint256 returnAmount = item.amount;

    item.owner = address(0);
    item.amount = 0;
    item.startTime = 0;
    item.endTime = 0;
    item.hasClaimed = true;

    IERC20Upgradeable(esP88).safeTransfer(msg.sender, returnAmount);

    emit Cancel(msg.sender, itemIndex, returnAmount);
  }

  function getUnlockAmount(uint256 amount, uint256 duration)
    public
    pure
    returns (uint256)
  {
    // x^1.5 model where x is the ratio of duration over MAX_DURATION, seconds in year
    // amount * (duration/MAX_DURATION) * sqrt(duration/MAX_DURATION)
    uint256 ratioX18 = Math.divWadDown(duration, YEAR);

    // Sqrt will result in 1e(18/2), bump back to 1e18
    uint256 sqrtRatio = Math.sqrt(ratioX18) * 1e9;

    return Math.mulWadDown(amount, (Math.mulWadDown(ratioX18, sqrtRatio)));
  }

  function nextItemId() external view returns (uint256) {
    return items.length;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
