// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/IDual.sol";
import "./interfaces/IPriceFeed.sol";
import "./interfaces/IVault.sol";

import "./libraries/math.sol";

contract DualFactory is AccessControl, IDualFactory {
  using SafeERC20 for ERC20;

  address public immutable WETH;

  mapping(uint256 => Dual) private _duals;
  uint32 public dualIndex;

  DualTariff[] private _tariffs;
  mapping(address => uint256[]) private _userDuals;
  address[] private _tokens;
  bool public enabled;

  IPriceFeed public priceFeed;
  IVault public vault;

  constructor(IVault _vault, IPriceFeed _priceFeed, address _WETH) {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

    vault = _vault;
    priceFeed = _priceFeed;
    WETH = _WETH;

    dualIndex = 0;
    enabled = true;
  }

  function create(uint256 tariffId, address _user, address inputToken, uint256 inputAmount) public {
    require(msg.sender == _user || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Dual: Not Allowed");

    DualTariff memory tariff = _tariffs[tariffId];

    _validate(tariff, inputToken, inputAmount);
    vault.depositTokens(inputToken, _user, inputAmount);
    _create(tariff, _user, inputToken, inputAmount);
  }

  function createETH(uint256 tariffId) public payable {
    DualTariff memory tariff = _tariffs[tariffId];
    address inputToken = address(WETH);
    uint256 inputAmount = msg.value;

    _validate(tariff, inputToken, inputAmount);
    vault.deposit{value: msg.value}();
    _create(tariff, msg.sender, inputToken, inputAmount);
  }

  function replay(uint256 id, uint256 tariffId, uint80 baseRoundId, uint80 quoteRoundId) public {
    (Dual memory dual, DualTariff memory tariff) = _close(id, baseRoundId, quoteRoundId);

    require(msg.sender == dual.user || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Dual: Access denied");

    (address inputToken, uint256 inputAmount) = _output(dual, tariff);

    if (tariff.id != tariffId) {
      tariff = _tariffs[tariffId];
    }

    _validate(tariff, inputToken, inputAmount);
    _create(tariff, dual.user, inputToken, inputAmount);

    emit DualReplayed(id);
  }

  function _validate(DualTariff memory tariff, address inputToken, uint256 inputAmount) private view {
    require(enabled, "Dual: Creating new duals is unavailable now");
    require(inputToken == tariff.baseToken || inputToken == tariff.quoteToken, "Dual: Input must be one from pair");
    require(tariff.enabled, "Dual: Tariff does not exist");

    if (tariff.baseToken == inputToken) {
      require(inputAmount >= tariff.minBaseAmount, "Dual: Too small input amount");
      require(inputAmount <= tariff.maxBaseAmount, "Dual: Exceeds maximum input amount");
    } else {
      require(inputAmount >= tariff.minQuoteAmount, "Dual: Too small input amount");
      require(inputAmount <= tariff.maxQuoteAmount, "Dual: Exceeds maximum input amount");
    }
  }

  function _create(DualTariff memory tariff, address _user, address inputToken, uint256 inputAmount) private {
    uint256 initialPrice = priceFeed.currentCrossPrice(tariff.baseToken, tariff.quoteToken);

    Dual memory dual;
    dual.user = _user;
    dual.tariffId = tariff.id;
    dual.initialPrice = initialPrice;
    dual.startedAt = block.timestamp;

    if (inputToken == tariff.baseToken) {
      dual.inputBaseAmount = inputAmount;
    } else {
      dual.inputQuoteAmount = inputAmount;
    }

    _duals[dualIndex] = dual;
    _userDuals[_user].push(dualIndex);

    emit DualCreated(dualIndex);
    dualIndex++;
  }

  function claim(uint256 id, uint80 baseRoundId, uint80 quoteRoundId) public {
    (Dual memory dual, DualTariff memory tariff) = _close(id, baseRoundId, quoteRoundId);
    require(msg.sender == dual.user || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Dual: Access denied");

    (address outputToken, uint256 outputAmount) = _output(dual, tariff);

    if (outputToken == address(WETH)) {
      vault.withdraw(payable(dual.user), outputAmount);
    } else {
      vault.withdrawTokens(outputToken, dual.user, outputAmount);
    }
  }

  function _close(
    uint256 id,
    uint80 baseRoundId,
    uint80 quoteRoundId
  ) private returns (Dual storage dual, DualTariff memory tariff) {
    dual = _duals[id];
    tariff = _tariffs[dual.tariffId];
    uint256 finishAt = dual.startedAt + (tariff.stakingPeriod * 1 hours);

    require(block.timestamp >= finishAt, "Dual: Not finished yet");
    require(dual.closedPrice == 0, "Dual: Already claimed");

    dual.closedPrice = priceFeed.historicalCrossPrice(
      tariff.baseToken,
      baseRoundId,
      tariff.quoteToken,
      quoteRoundId,
      finishAt
    );

    emit DualClaimed(id);
  }

  function get(uint256 id) public view returns (Dual memory dual) {
    dual = _duals[id];
    DualTariff memory tariff = _tariffs[dual.tariffId];

    dual.id = id;
    dual.baseToken = tariff.baseToken;
    dual.quoteToken = tariff.quoteToken;
    dual.stakingPeriod = tariff.stakingPeriod;
    dual.yield = tariff.yield;
    dual.finishAt = dual.startedAt + (tariff.stakingPeriod * 1 hours);

    (dual.inputToken, dual.inputAmount) = _input(dual, tariff);
    (dual.outputToken, dual.outputAmount) = _output(dual, tariff);

    if (dual.outputAmount > 0) {
      dual.claimed = true;
    }
  }

  function _input(
    Dual memory dual,
    DualTariff memory tariff
  ) private pure returns (address inputToken, uint256 inputAmount) {
    if (dual.inputBaseAmount > 0) {
      inputToken = tariff.baseToken;
      inputAmount = dual.inputBaseAmount;
    } else {
      inputToken = tariff.quoteToken;
      inputAmount = dual.inputQuoteAmount;
    }
  }

  function _output(
    Dual memory dual,
    DualTariff memory tariff
  ) private view returns (address outputToken, uint256 outputAmount) {
    if (dual.closedPrice == 0) return (address(0), 0);

    if (dual.closedPrice >= dual.initialPrice) {
      outputToken = tariff.quoteToken;

      if (dual.inputQuoteAmount > 0) {
        outputAmount = dual.inputQuoteAmount + Math.percent(dual.inputQuoteAmount, tariff.yield);
      } else {
        uint256 baseTokenDecimals = 10 ** ERC20(tariff.baseToken).decimals();
        outputAmount = (dual.inputBaseAmount * dual.initialPrice) / baseTokenDecimals;
        outputAmount = outputAmount + Math.percent(outputAmount, tariff.yield);
      }
    } else {
      outputToken = tariff.baseToken;

      if (dual.inputBaseAmount > 0) {
        outputAmount = dual.inputBaseAmount + Math.percent(dual.inputBaseAmount, tariff.yield);
      } else {
        uint256 baseTokenDecimals = 10 ** ERC20(tariff.baseToken).decimals();
        outputAmount = (dual.inputQuoteAmount * baseTokenDecimals) / dual.initialPrice;
        outputAmount = outputAmount + Math.percent(outputAmount, tariff.yield);
      }
    }
  }

  function countUserOpenedDuals(address _user) public view returns (uint256 count) {
    uint256[] memory dualIds = _userDuals[_user];
    uint256 length = dualIds.length;

    for (uint256 i = length; i > 0; i--) {
      Dual memory dual = get(dualIds[i - 1]);

      if (!dual.claimed && dual.finishAt > block.timestamp) count++;
    }
  }

  function userOpenedDuals(address _user, uint256 limit, uint256 offset) public view returns (Dual[] memory duals) {
    uint256[] memory dualIds = _userDuals[_user];
    uint256 length = dualIds.length;
    duals = new Dual[](limit);
    uint256 j = 0;

    for (uint256 i = length; i > 0; i--) {
      Dual memory dual = get(dualIds[i - 1]);

      if (dual.claimed || dual.finishAt < block.timestamp) continue;

      if (offset > 0) {
        offset--;
      } else {
        duals[j++] = dual;

        if (j == limit) return duals;
      }
    }

    Dual[] memory openedDuals = new Dual[](j);
    for (uint256 i = 0; i < j; i++) {
      openedDuals[i] = duals[i];
    }

    return openedDuals;
  }

  function countUserClosedDuals(address _user) public view returns (uint256 count) {
    uint256[] memory dualIds = _userDuals[_user];
    uint256 length = dualIds.length;

    for (uint256 i = length; i > 0; i--) {
      Dual memory dual = get(dualIds[i - 1]);

      if (!dual.claimed && dual.finishAt < block.timestamp) count++;
    }
  }

  function userClosedDuals(address _user, uint256 limit, uint256 offset) public view returns (Dual[] memory duals) {
    uint256[] memory dualIds = _userDuals[_user];
    uint256 length = dualIds.length;
    duals = new Dual[](limit);
    uint256 j = 0;

    for (uint256 i = length; i > 0; i--) {
      Dual memory dual = get(dualIds[i - 1]);

      if (dual.claimed || dual.finishAt > block.timestamp) continue;

      if (offset > 0) {
        offset--;
      } else {
        duals[j++] = dual;

        if (j == limit) return duals;
      }
    }

    Dual[] memory closedDuals = new Dual[](j);
    for (uint256 i = 0; i < j; i++) {
      closedDuals[i] = duals[i];
    }

    return closedDuals;
  }

  function countUserClaimedDuals(address _user) public view returns (uint256 count) {
    uint256[] memory dualIds = _userDuals[_user];
    uint256 length = dualIds.length;

    for (uint256 i = length; i > 0; i--) {
      Dual memory dual = get(dualIds[i - 1]);

      if (dual.claimed) count++;
    }
  }

  function userClaimedDuals(address _user, uint256 limit, uint256 offset) public view returns (Dual[] memory duals) {
    uint256[] memory dualIds = _userDuals[_user];
    uint256 length = dualIds.length;
    duals = new Dual[](limit);
    uint256 j = 0;

    for (uint256 i = length; i > 0; i--) {
      Dual memory dual = get(dualIds[i - 1]);

      if (!dual.claimed) continue;

      if (offset > 0) {
        offset--;
      } else {
        duals[j++] = dual;

        if (j == limit) return duals;
      }
    }

    Dual[] memory claimedDuals = new Dual[](j);
    for (uint256 i = 0; i < j; i++) {
      claimedDuals[i] = duals[i];
    }

    return claimedDuals;
  }

  function user(address _user) public view returns (uint256[] memory) {
    return _userDuals[_user];
  }

  function addTariff(DualTariff memory dualTariff) public onlyRole(DEFAULT_ADMIN_ROLE) {
    dualTariff.id = _tariffs.length;
    _tariffs.push(dualTariff);
  }

  function enableTariff(uint256 id) public onlyRole(DEFAULT_ADMIN_ROLE) {
    DualTariff storage tariff = _tariffs[id];
    tariff.enabled = true;
  }

  function disableTariff(uint256 id) public onlyRole(DEFAULT_ADMIN_ROLE) {
    DualTariff storage tariff = _tariffs[id];
    tariff.enabled = false;
  }

  function tariffs() public view returns (DualTariff[] memory dt1) {
    dt1 = new DualTariff[](_tariffs.length);
    uint256 j = 0;
    uint256 i = 0;

    for (i = 0; i < _tariffs.length; i++) {
      if (_tariffs[i].enabled) {
        dt1[j++] = _tariffs[i];
      }
    }

    if (i == j) return dt1;

    DualTariff[] memory dt2 = new DualTariff[](j);
    for (i = 0; i < j; i++) {
      dt2[i] = dt1[i];
    }

    return dt2;
  }

  function enable() public onlyRole(DEFAULT_ADMIN_ROLE) {
    enabled = true;
  }

  function disable() public onlyRole(DEFAULT_ADMIN_ROLE) {
    enabled = false;
  }

  function updateVault(IVault _vault) public onlyRole(DEFAULT_ADMIN_ROLE) {
    emit VaultUpdated(address(vault), address(_vault));
    vault = _vault;
  }

  function updatePriceFeed(IPriceFeed _priceFeed) public onlyRole(DEFAULT_ADMIN_ROLE) {
    emit PriceFeedUpdated(address(priceFeed), address(_priceFeed));
    priceFeed = _priceFeed;
  }
}
