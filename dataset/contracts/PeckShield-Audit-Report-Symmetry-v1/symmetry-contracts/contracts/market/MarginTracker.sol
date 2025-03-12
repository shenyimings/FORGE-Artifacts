// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../utils/SignedSafeDecimalMath.sol";
import "../utils/Initializable.sol";
import "../utils/CommonContext.sol";

import "../interfaces/IMarginTracker.sol";
import "../interfaces/IMarket.sol";
import "../interfaces/IMarketSettings.sol";
import "../interfaces/IPerpTracker.sol";
import "../interfaces/IDebtInterestRateModel.sol";

import "./MarketSettingsContext.sol";

contract MarginTracker is IMarginTracker, CommonContext, MarketSettingsContext, AccessControlEnumerable, Initializable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SignedSafeDecimalMath for int;
    using SafeCast for int;

    // reserved storage slots for base contract upgrade in future
    uint[50] private __gap;

    // states
    address public market;
    address public baseToken;
    address public settings;
    EnumerableSet.AddressSet private collateralTokens; // collaterals
    // account => token => amount mapping
    mapping(address => mapping(address => int)) public userCollaterals;
    mapping(address => int) public totalCollaterals;
    mapping(address => int) public freezed; // freezed user margin in baseToken for keeper fee
    address public interestRateModel;

    // total debt, the debt is directly settled with base token so its decimals is the same as base token
    int public totalDebt;

    // NOTE: following states should use 18 decimals because when decimals of base token is too small,
    // e.g. USDC whose decimals equals 6, the precision loss can be significant if total debt is huge.
    int public accDebt; // accumulative debt per negative base collateral,
    int public unsettledInterest; // generated interest but not settled yet
    mapping(address => int) public userAccDebts; // user acc debts

    modifier onlyMarket() {
        require(msg.sender == market, "MarginTracker: sender is not market");
        _;
    }

    /*=== initialize ===*/

    function initialize(address _market, address _interestRateModel) external onlyInitializeOnce {
        market = _market;
        interestRateModel = _interestRateModel;
        baseToken = IMarket(_market).baseToken();
        settings = IMarket(_market).settings();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /*=== tokens ===*/

    function addCollateralToken(address _token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (collateralTokens.add(_token)) {
            emit NewCollateral(_token);
        }
    }

    function removeCollateralToken(address _token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (collateralTokens.remove(_token)) {
            emit RemoveCollateral(_token);
        }
    }

    /*=== pure functions ===*/

    function domainKey(address _token) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_token, MARGIN_DOMAIN));
    }

    /*=== view functions ===*/

    function collateralTokensLength() external view returns (uint) {
        return collateralTokens.length();
    }

    function collateralTokensList(uint _idx) external view returns (address) {
        return collateralTokens.at(_idx);
    }

    function collateralTokensListed(address _token) external view returns (bool) {
        return collateralTokens.contains(_token);
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return collateralTokens.values();
    }

    function _userBaseBalance(address _account) internal view returns (int balance) {
        (int nextAccDebt, ) = nextDebt();
        balance = userCollaterals[_account][baseToken];
        int lastAccDebt = userAccDebts[_account];
        if (balance < 0 && nextAccDebt > lastAccDebt) {
            balance += (balance * (nextAccDebt - lastAccDebt)) / _UNIT;
        }
    }

    function accountMargin(address _account) external view returns (int baseMargin, int otherMargin) {
        IMarket market_ = IMarket(market);
        IMarketSettings settings_ = IMarketSettings(settings);

        address[] memory tokens = collateralTokens.values();
        for (uint i = 0; i < tokens.length; ++i) {
            if (tokens[i] == baseToken) {
                int balance = _userBaseBalance(_account);
                if (balance >= 0) {
                    baseMargin = market_.baseTokenToUsd(balance, false);
                } else if (balance < 0) {
                    baseMargin = market_.baseTokenToUsd(balance, true);
                }
            } else {
                int balance = userCollaterals[_account][tokens[i]];
                if (balance != 0) {
                    otherMargin += market_.tokenToUsd(tokens[i], balance).multiplyDecimal(
                        settings_.getIntValsByDomain(domainKey(tokens[i]), CONVERSION_RATIO)
                    );
                }
            }
        }
    }

    function _onlyBase(address _account) internal view returns (bool) {
        address[] memory tokens = collateralTokens.values();
        for (uint i = 0; i < tokens.length; ++i) {
            if (tokens[i] != baseToken && userCollaterals[_account][tokens[i]] != 0) {
                return false;
            }
        }
        return true;
    }

    /*=== debt ===*/
    function _updateAccDebt() internal {
        (int nextAccDebt, int nextUnsettledInterest) = nextDebt();
        accDebt = nextAccDebt;
        unsettledInterest = nextUnsettledInterest;
        IDebtInterestRateModel(interestRateModel).updateMaxInterestRate();

        emit DebtUpdated(accDebt);
    }

    function _updateUserDebt(address _account) internal {
        _updateAccDebt();

        int lastAccDebt = userAccDebts[_account];
        int amount = userCollaterals[_account][baseToken];
        if (amount < 0 && lastAccDebt < accDebt) {
            // settle interest, update user acc debt
            int delta = (amount * (accDebt - lastAccDebt)) / _UNIT;
            _modifyBaseMargin(_account, delta);
            unsettledInterest += (delta * _UNIT) / int(10 ** IERC20Metadata(baseToken).decimals());
            IMarket(market).sendToLp(-delta);
            // update accDebt
            userAccDebts[_account] = accDebt;

            emit UserDebtUpdated(_account, accDebt);
        }
    }

    function nextDebt() public view returns (int nextAccDebt, int nextUnsettledInterest) {
        nextAccDebt = accDebt;
        nextUnsettledInterest = unsettledInterest;

        int newInterest = IDebtInterestRateModel(interestRateModel).nextInterest();
        if (newInterest > 0) {
            int delta = (newInterest * _UNIT) / totalDebt;
            nextAccDebt += delta;
            nextUnsettledInterest += (delta * totalDebt) / int(10 ** IERC20Metadata(baseToken).decimals());
        }
    }

    function updateDebt(int _lpNetValue, int _netSkew) external onlyMarket {
        _updateAccDebt();

        int debtRatio = IMarketSettings(settings).getIntVals(MAX_DEBT_RATIO);
        if (_lpNetValue - _netSkew > 0) {
            debtRatio = debtRatio.min(
                IMarket(market).baseTokenToUsd(totalDebt, true).divideDecimal(_lpNetValue - _netSkew)
            );
        }
        IDebtInterestRateModel(interestRateModel).update(totalDebt, debtRatio);
    }

    /*=== margin ===*/
    function _modifyBaseMargin(address _account, int _delta) internal {
        if (_delta == 0) return;

        int oldMargin = userCollaterals[_account][baseToken];
        int newMargin = oldMargin + _delta;
        // update user
        userCollaterals[_account][baseToken] = newMargin;
        // update total debt
        totalDebt += (newMargin < 0 ? -newMargin : int(0)) + (oldMargin < 0 ? oldMargin : int(0));

        emit MarginTransferred(_account, baseToken, _delta);
    }

    function _modifyMargin(address _account, address _token, int _delta) internal {
        require(collateralTokens.contains(_token), "MarginTracker: invalid token");

        if (_token == baseToken) {
            _updateUserDebt(_account);
            _modifyBaseMargin(_account, _delta);
        } else {
            userCollaterals[_account][_token] += _delta;
            totalCollaterals[_token] += _delta;
            require(
                _delta < 0 ||
                    totalCollaterals[_token] <=
                    IMarketSettings(settings).getIntValsByDomain(domainKey(_token), COLLATERAL_CAP),
                "MarginTracker: collateral exceed cap"
            );

            emit MarginTransferred(_account, _token, _delta);
        }
    }

    function modifyMargin(address _account, address _token, int _delta) public onlyMarket {
        _modifyMargin(_account, _token, _delta);
    }

    function withdrawMargin(address _account, address _token, int _amount) external onlyMarket {
        require(_amount > 0, "MarginTracker: invalid amount");
        if (_token != baseToken) {
            require(userCollaterals[_account][_token] >= _amount, "MarginTracker: insufficient margin");
        } else {
            _updateUserDebt(_account);
            int withdrawable = userCollaterals[_account][_token];
            // it is always withdrawable if margin balance is sufficient
            if (withdrawable < _amount) {
                IMarket market_ = IMarket(market);
                // this settle could be failed if the account holds too many positions
                // the account owner can manually settle holding positions before withdrawal
                withdrawable += market_.settle(_account, IPerpTracker(market_.perpTracker()).getMarketTokens());
                require(withdrawable >= _amount, "MarginTracker: insufficient margin + pnl");
            }
        }
        _modifyMargin(_account, _token, -_amount);
    }

    function freeze(address _account, int _amount) external onlyMarket {
        freezed[_account] += _amount;
        _modifyMargin(_account, baseToken, -_amount);
    }

    function unfreeze(address _account, int _amount, address _receiver) external onlyMarket {
        require(freezed[_account] >= _amount, "MarginTracker: insufficient freezed margin");
        freezed[_account] -= _amount;
        _modifyMargin(_receiver, baseToken, _amount);
    }

    function _transfer(address _from, address _to, address _token, int _amount) internal {
        _modifyMargin(_from, _token, -_amount);
        _modifyMargin(_to, _token, _amount);
    }

    function transferByMarket(address _from, address _to, address _token, int _amount) external onlyMarket {
        _transfer(_from, _to, _token, _amount);
    }

    /*=== liquidate ===*/
    function coverDeficitLoss(address _account) external {
        _coverDeficitLoss(_account);
    }

    function _coverDeficitLoss(address _account) internal returns (bool onlyBase, int balance) {
        onlyBase = _onlyBase(_account);
        balance = userCollaterals[_account][baseToken];
        if (onlyBase && balance < 0) {
            _modifyMargin(_account, baseToken, -balance);
            (uint insuranceOut, uint lpOut) = IMarket(market).coverDeficitLoss(-balance);
            emit DeficitLoss(_account, (-balance).toUint256(), insuranceOut, lpOut);
        }
    }

    function liquidate(address _account, address _token, uint _maxAmount) external payable {
        require(collateralTokens.contains(_token) && _token != baseToken, "MarginTracker: invalid token");

        IMarket market_ = IMarket(market);
        IMarketSettings settings_ = IMarketSettings(settings);
        // settle debt interest
        _updateUserDebt(_account);
        // validation
        {
            (, int currentMargin, , int positionNotional) = market_.accountMarginStatus(_account);
            require(positionNotional == 0, "MarginTracker: non-zero position notional");
            require(currentMargin < 0, "MarginTracker: non-negative margin");
        }
        int liquidateAmount = userCollaterals[_account][_token];
        int baseAmount = market_.usdToToken(baseToken, market_.tokenToUsd(_token, liquidateAmount));
        require(baseAmount > 0, "MarginTracker: nothing to repay");
        uint repayAmount = baseAmount
            .multiplyDecimal(settings_.getIntValsByDomain(domainKey(_token), FLOOR_PRICE_RATIO))
            .toUint256();
        require(_maxAmount >= repayAmount, "MarginTracker: price mismatch");
        // liquidate
        market_.transferMarginIn{value: msg.value}(msg.sender, _account, baseToken, repayAmount);
        market_.transferMarginOut(_account, msg.sender, _token, liquidateAmount.toUint256());
        // pay liquidation fee or cover deficit loss
        int penalty = baseAmount.multiplyDecimal(settings_.getIntVals(COLLATERAL_LIQUIDATION_PENALTY));
        {
            (bool onlyBase, int balance) = _coverDeficitLoss(_account);
            if (onlyBase) {
                if (balance < 0) {
                    // covered deficit loss
                    market_.updateDebt();
                    emit Liquidated(_account, _token, uint(liquidateAmount), repayAmount, 0, 0, uint(-balance));
                    return;
                } else {
                    penalty = penalty.min(balance);
                }
            }
        }
        // pay penalty to lp & treasury
        int toLp = penalty.multiplyDecimal(settings_.getIntVals(COLLATERAL_PENALTY_TO_LP));
        toLp = toLp.min(penalty).max(0);
        if (toLp > 0) {
            market_.deductFeeToLiquidity(_account, toLp);
        }
        if (penalty - toLp > 0) {
            _transfer(_account, market_.treasury(), baseToken, penalty - toLp);
        }

        // update debt
        market_.updateDebt();

        emit Liquidated(
            _account,
            _token,
            uint(liquidateAmount),
            repayAmount,
            toLp.toUint256(),
            (penalty - toLp).toUint256(),
            0
        );
    }
}
