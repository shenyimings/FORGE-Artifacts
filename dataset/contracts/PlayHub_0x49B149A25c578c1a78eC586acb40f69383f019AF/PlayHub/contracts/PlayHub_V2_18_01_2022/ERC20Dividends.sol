// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./ERC20.sol";

abstract contract ERC20Dividends is ERC20 {
    uint256 private magnifier = 10**18;

    uint256 internal _minimumBalanceForDividends;

    uint256 internal totalDividends = 0; // only increase
    uint256 private unpaid = 0;
    uint256 private totalDividendable = 0; // sum of balances with minimum for Dividends

    // mapping(address => bool) private isDividendable;
    mapping(address => uint256) private dividendableBalance;
    mapping(address => uint256) private snapTotalForLastPay;

    mapping (address => bool) public isDividendsExcluded;
    mapping (address => uint256) public dividedsLastClaimTime;

    mapping (address => uint256) public paidDividendsTo;

    uint256 internal _dividendsClaimWait;

    /// EVENTS
    event ExcludeFromDividends(address indexed holder);
    event IncludeInDividends(address indexed holder);
    event DividendsClaimWaitUpdated(uint256 newValue, uint256 oldValue);
    event DividendsClaim(address indexed account, uint256 amount);

    function addDividends(uint256 dividendsAmount) internal {
        totalDividends += dividendsAmount;
        unpaid += dividendsAmount;
    }

    function maybeProcessDividendsFor(address holder) internal {
        if (isDividendable(holder) && totalDividends > snapTotalForLastPay[holder]) {
            uint256 deltaDividends = totalDividends - snapTotalForLastPay[holder];

            uint256 dividendsPerTokenMagnified = deltaDividends * magnifier / totalDividendable;
            uint256 dividends = balanceOf(holder) * dividendsPerTokenMagnified / magnifier;

            snapTotalForLastPay[holder] = totalDividends;
            unpaid -= dividends;
            paidDividendsTo[holder] += dividends;

            super._transfer(address(this), holder, dividends); 
        }
    }

    function updateDividendability(address holder) internal {
        if (isDividendsExcluded[holder]) {
            if (isDividendable(holder)) {
                totalDividendable -= dividendableBalance[holder];
                dividendableBalance[holder] = 0;
            }
        }
        else {
            bool shouldReceiveDividends = (balanceOf(holder) >= _minimumBalanceForDividends);
            if (shouldReceiveDividends) { 
                if (isDividendable(holder)) {
                    totalDividendable = totalDividendable + balanceOf(holder) - dividendableBalance[holder];
                    dividendableBalance[holder] = balanceOf(holder);
                }
                else {
                    totalDividendable += balanceOf(holder);
                    dividendableBalance[holder] = balanceOf(holder);
                    snapTotalForLastPay[holder] = totalDividends;
                }
            }
            else { 
                if (isDividendable(holder)) {
                    totalDividendable -= dividendableBalance[holder];
                    dividendableBalance[holder] = 0;
                }
            }
        }

    }

    function isDividendable(address holder) view public returns (bool) {
        return (dividendableBalance[holder] > 0);
    }

    function claimDividends(address holder) internal {
        require(!isDividendsExcluded[holder], "Account excluded from dividends");
        require(isDividendable(holder), "Condition for dividends NOT met");
        require(totalDividends > snapTotalForLastPay[holder], "All dividends already paid");

        maybeProcessDividendsFor(holder);
    }

    function _excludeFromDividends(address holder) internal {
        require(!isDividendsExcluded[holder]);
        isDividendsExcluded[holder] = true;

        if (isDividendable(holder)) {
            totalDividendable -= dividendableBalance[holder];
            dividendableBalance[holder] = 0;
        }

        emit ExcludeFromDividends(holder);
    }

    function _includeInDividends(address holder) internal {
        require(isDividendsExcluded[holder]);
        isDividendsExcluded[holder] = false;
        emit IncludeInDividends(holder);
    }

    function _updateDividendsClaimWait(uint256 newDividendsClaimWait) internal {
        require(newDividendsClaimWait >= 3600 && newDividendsClaimWait <= 86400, "dividendsClaimWait must be between 1 and 24 hours");
        require(newDividendsClaimWait != _dividendsClaimWait, "Cannot update dividendsClaimWait to same value");
        emit DividendsClaimWaitUpdated(newDividendsClaimWait, _dividendsClaimWait);
        _dividendsClaimWait = newDividendsClaimWait;
    }

    function _updateDividendsMinimum(uint256 minimumToEarnDivs) internal {
        require(minimumToEarnDivs != _minimumBalanceForDividends, "Cannot update DividendsMinimum to same value");
        _minimumBalanceForDividends = minimumToEarnDivs;
    }

    function _withdrawableDividendOf(address holder) internal view returns(uint256) {
        uint256 dividends = 0;
        if (isDividendable(holder) && totalDividends > snapTotalForLastPay[holder]) {
            uint256 deltaDividends = totalDividends - snapTotalForLastPay[holder];
            uint256 dividendsPerTokenMagnified = deltaDividends * magnifier / totalDividendable;
            dividends = balanceOf(holder) * dividendsPerTokenMagnified / magnifier;
        }

        return dividends;
    }
}