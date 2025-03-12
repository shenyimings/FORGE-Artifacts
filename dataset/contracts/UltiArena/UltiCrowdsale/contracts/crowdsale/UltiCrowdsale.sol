// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './extension/Crowdsale.sol';
import './extension/TimedCrowdsale.sol';
import './extension/PostVestingCrowdsale.sol';
import './extension/WhitelistAccess.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';

contract UltiCrowdsale is Crowdsale, TimedCrowdsale, PostVestingCrowdsale, WhitelistAccess {
    enum CrowdsaleStage {Inactive, GuaranteedSpot, PrivateSale, Presale1, Presale2, Presale3, Presale4, Presale5}

    struct CrowdsaleStageData {
        uint256 closingTime;
        uint256 rate;
        uint256 bonus;
        uint256 cap;
        uint256 minContribution;
        uint256 maxContribution;
        uint256 weiRaised;
        mapping(address => uint256) contributions;
    }

    mapping(CrowdsaleStage => CrowdsaleStageData) private _stages;

    uint256 public constant OPENING_TIME = 1623427200; // 11-06-2021 16:00 UTC
    uint256 public constant CLOSING_TIME = 1631451600; // 12-09-2021 13:00 UTC

    bytes32 public constant GUARANTEED_SPOT_WHITELIST = keccak256('GUARANTEED_SPOT_WHITELIST');
    bytes32 public constant PRIVATE_SALE_WHITELIST = keccak256('PRIVATE_SALE_WHITELIST');
    bytes32 public constant KYCED_WHITELIST = keccak256('KYCED_WHITELIST');

    uint256 public constant VESTING_START_OFFSET = 864000; // 10 days
    uint256 public constant VESTING_CLIFF_DURATION = 864000; // 10 days
    uint256 public constant VESTING_DURATION = 8640000; // 100 days
    uint256 public constant VESTING_INITIAL_PERCENT = 10; // 10 %

    constructor(
        address admin_,
        address payable wallet_,
        IERC20Burnable token_
    )
        Crowdsale(1, wallet_, token_)
        TimedCrowdsale(OPENING_TIME, CLOSING_TIME)
        PostVestingCrowdsale(VESTING_START_OFFSET, VESTING_CLIFF_DURATION, VESTING_DURATION, VESTING_INITIAL_PERCENT)
        WhitelistAccess(admin_)
    {
        _setupStage(CrowdsaleStage.Inactive, 0, 0, 0, 0, 0, 0);
        // closing: 12-06-2021 16:00 UTC, price: 0.00000019 BNB, bonus: 30%, cap: 2500 BNB, min: 0.5 BNB, max: 5 BNB
        _setupStage(CrowdsaleStage.GuaranteedSpot, 1623513600, 4000000, 30, 2500 * 1e18, 5 * 1e17, 5 * 1e18);
        // closing: 26-06-2021 16:00 UTC, price: 0.00000019 BNB, bonus: 30%, cap: 2500 BNB, min: 0.5 BNB, max: 5 BNB
        _setupStage(CrowdsaleStage.PrivateSale, 1624723200, 4000000, 30, 2500 * 1e18, 5 * 1e17, 5 * 1e18);
        // closing: 10-07-2021 16:00 UTC, price: 0.00000045 BNB, bonus: 10%, cap: 3500 BNB, min: 1 BNB, max: 10 BNB
        _setupStage(CrowdsaleStage.Presale1, 1625932800, 2000000, 10, 3500 * 1e18, 1 * 1e18, 10 * 1e18);
        // closing: 24-07-2021 16:00 UTC, price: 0.00000071 BNB, bonus: 5%, cap: 6000 BNB, min: 1 BNB, max: 20 BNB
        _setupStage(CrowdsaleStage.Presale2, 1627142400, 1333333, 5, 6000 * 1e18, 1 * 1e18, 20 * 1e18);
        // closing: 07-08-2021 16:00 UTC, price: 0.00000097 BNB, bonus: 3%, cap: 9000 BNB, min: 1 BNB, max: 30 BNB
        _setupStage(CrowdsaleStage.Presale3, 1628352000, 1000000, 3, 9000 * 1e18, 1 * 1e18, 30 * 1e18);
        // closing: 21-08-2021 16:00 UTC, price: 0.00000125 BNB, bonus: 0%, cap: 12500 BNB, min: 1 BNB, max: 50 BNB
        _setupStage(CrowdsaleStage.Presale4, 1629561600, 800000, 0, 12500 * 1e18, 1 * 1e18, 50 * 1e18);
        // closing: 12-09-2021 13:00 UTC, price: 0.00000150 BNB, bonus: 0%, cap: 16500 BNB, min: 1 BNB, max: 100 BNB
        _setupStage(CrowdsaleStage.Presale5, 1631451600, 666667, 0, 16500 * 1e18, 1 * 1e18, 100 * 1e18);
    }

    modifier onlyInContributionLimits(address beneficiary, uint256 weiAmount) {
        require(weiAmount > 0, 'UltiCrowdsale: the value sent is zero');
        require(
            weiContributedInStage(_currentStage(), beneficiary) + weiAmount >= minContribution(),
            'UltiCrowdsale: the value sent is insufficient for the minimal contribution'
        );
        require(
            weiAmount <= _weiToContributionLimit(beneficiary),
            'UltiCrowdsale: the value sent exceeds the maximum contribution'
        );
        _;
    }

    function rate() public view override(Crowdsale) returns (uint256) {
        return _stages[_currentStage()].rate;
    }

    function bonus() public view returns (uint256) {
        return _stages[_currentStage()].bonus;
    }

    function minContribution() public view returns (uint256) {
        return _stages[_currentStage()].minContribution;
    }

    function maxContribution() public view returns (uint256) {
        return _stages[_currentStage()].maxContribution;
    }

    function cap() external view returns (uint256) {
        return _stages[_currentStage()].cap;
    }

    function stage() external view returns (CrowdsaleStage) {
        return _currentStage();
    }

    function weiContributed(address account) external view returns (uint256) {
        uint256 _weiContributed = 0;
        for (uint256 i = uint256(CrowdsaleStage.GuaranteedSpot); i <= uint256(CrowdsaleStage.Presale5); i++) {
            _weiContributed = _weiContributed + _stages[CrowdsaleStage(i)].contributions[account];
        }
        return _weiContributed;
    }

    function weiContributedInStage(CrowdsaleStage stage_, address account) public view returns (uint256) {
        return _stages[stage_].contributions[account];
    }

    function weiRaisedInStage(CrowdsaleStage stage_) external view returns (uint256) {
        return _stages[stage_].weiRaised;
    }

    function weiToStageCap() external view returns (uint256) {
        return _weiToStageCap();
    }

    function isWhitelistedForCurrentStage(address account) external view returns (bool) {
        return _isCorrectlyWhitelisted(account);
    }

    function releaseTokens(address beneficiary) external {
        require(beneficiary != address(0), 'UltiCrowdsale: beneficiary is the zero address');
        require(_isWhitelisted(KYCED_WHITELIST, beneficiary), 'UltiCrowdsale: beneficiary is not on whitelist');
        return _releaseTokens(beneficiary);
    }

    function burn(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasClosed(), 'UltiCrowdsale: crowdsale not closed');
        uint256 crowdsaleBalance = token().balanceOf(address(this));
        uint256 tokensToBeReleased = tokensSold() - tokensReleased();
        require(crowdsaleBalance - amount >= tokensToBeReleased, 'UltiCrowdsale: unreleased tokens can not be burned');
        token().burn(amount);
    }

    /*
        This is a super emergency mechanism. It allows changing token address before the crowdsale
        is ended and vesting is started. The whole idea is to protect the Ulti Arena project and
        its investors from the situation that all of us are stuck with the bugs in the token contract.
        
        A great feature of this crowdsale is that all transfers happen after the end date, so until
        then if some bad scenario happens, we can fix bugs, redeploy the token contract, and swap
        the token address to the new one. The state of this crowdsale, tokens sold and wei raised
        counters stay intact.
    */
    function changeTokenAddress(IERC20Burnable token_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!hasClosed(), 'UltiCrowdsale: crowdsale is closed');
        return _setToken(token_);
    }

    function _preValidatePurchase(address beneficiary, uint256 weiAmount)
        internal
        view
        override(Crowdsale, TimedCrowdsale)
        onlyWhileOpen
        onlyInContributionLimits(beneficiary, weiAmount)
    {
        Crowdsale._preValidatePurchase(beneficiary, weiAmount);
        require(weiAmount <= _weiToStageCap(), 'UltiCrowdsale: value sent exceeds cap of stage');
        require(_isCorrectlyWhitelisted(beneficiary), 'UltiCrowdsale: beneficiary is not on whitelist');
    }

    function _getTokenAmount(uint256 weiAmount) internal view override(Crowdsale) returns (uint256) {
        uint256 amount = weiAmount * rate();
        uint256 _bonus = (amount * bonus()) / 100;
        return amount + _bonus;
    }

    function _processPurchase(address beneficiary, uint256 tokenAmount)
        internal
        override(Crowdsale, PostVestingCrowdsale)
    {
        PostVestingCrowdsale._processPurchase(beneficiary, tokenAmount);
    }

    function _updatePurchasingState(address beneficiary, uint256 weiAmount) internal override(Crowdsale) {
        CrowdsaleStage stage_ = _currentStage();
        _stages[stage_].weiRaised = _stages[stage_].weiRaised + weiAmount;
        _stages[stage_].contributions[beneficiary] = _stages[stage_].contributions[beneficiary] + weiAmount;
    }

    function _currentStage() private view returns (CrowdsaleStage) {
        if (!isOpen()) {
            return CrowdsaleStage.Inactive;
        }

        uint256 lastBlockTimestamp = block.timestamp;

        if (lastBlockTimestamp > _stages[CrowdsaleStage.Presale4].closingTime) {
            return CrowdsaleStage.Presale5;
        } else if (lastBlockTimestamp > _stages[CrowdsaleStage.Presale3].closingTime) {
            return CrowdsaleStage.Presale4;
        } else if (lastBlockTimestamp > _stages[CrowdsaleStage.Presale2].closingTime) {
            return CrowdsaleStage.Presale3;
        } else if (lastBlockTimestamp > _stages[CrowdsaleStage.Presale1].closingTime) {
            return CrowdsaleStage.Presale2;
        } else if (lastBlockTimestamp > _stages[CrowdsaleStage.PrivateSale].closingTime) {
            return CrowdsaleStage.Presale1;
        } else if (lastBlockTimestamp > _stages[CrowdsaleStage.GuaranteedSpot].closingTime) {
            return CrowdsaleStage.PrivateSale;
        } else {
            return CrowdsaleStage.GuaranteedSpot;
        }
    }

    function _isCorrectlyWhitelisted(address beneficiary) private view returns (bool) {
        bool isKycedWhitelisted = _isWhitelisted(KYCED_WHITELIST, beneficiary);
        bool isGuaranteedSpotWhitelisted = _isWhitelisted(GUARANTEED_SPOT_WHITELIST, beneficiary);
        bool isPrivateSaleWhitelisted = _isWhitelisted(PRIVATE_SALE_WHITELIST, beneficiary);
        if (_currentStage() == CrowdsaleStage.GuaranteedSpot) {
            return isGuaranteedSpotWhitelisted;
        } else if (_currentStage() == CrowdsaleStage.PrivateSale) {
            return isGuaranteedSpotWhitelisted || isPrivateSaleWhitelisted;
        } else {
            return isKycedWhitelisted;
        }
    }

    function _weiToStageCap() private view returns (uint256) {
        CrowdsaleStage stage_ = _currentStage();
        uint256 extraAmount = 0;
        // In order to sum up raised amounts in GuaranteedSpot and PrivateSale stages
        if (stage_ == CrowdsaleStage.PrivateSale) {
            extraAmount = _stages[CrowdsaleStage.GuaranteedSpot].weiRaised;
        }
        return _stages[stage_].cap - _stages[stage_].weiRaised - extraAmount;
    }

    function _weiToContributionLimit(address account) private view returns (uint256) {
        CrowdsaleStage stage_ = _currentStage();
        uint256 extraAmount = 0;
        // In order to sum up raised amounts in GuaranteedSpot and PrivateSale stages
        if (stage_ == CrowdsaleStage.PrivateSale) {
            extraAmount = weiContributedInStage(CrowdsaleStage.GuaranteedSpot, account);
        }
        return maxContribution() - weiContributedInStage(stage_, account) - extraAmount;
    }

    function _setupStage(
        CrowdsaleStage stage_,
        uint256 closingTime_,
        uint256 rate_,
        uint256 bonus_,
        uint256 cap_,
        uint256 minContribution_,
        uint256 maxContribution_
    ) private {
        _stages[stage_].closingTime = closingTime_;
        _stages[stage_].rate = rate_;
        _stages[stage_].bonus = bonus_;
        _stages[stage_].cap = cap_;
        _stages[stage_].minContribution = minContribution_;
        _stages[stage_].maxContribution = maxContribution_;
    }
}
